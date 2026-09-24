#!/usr/bin/env ruby
# frozen_string_literal: true

# 指定時刻より後に Copilot が PR に投稿したレビューを待ち、届いたら JSON で標準出力する。
# 使い方: ruby wait_for_copilot_review.rb <owner/repo> <pr_number> <since(ISO 8601)> [timeout_sec]
#
# 終了コード: 0 = レビューが届いた / 2 = タイムアウト
# 依存: gh CLI（認証済み）

require "json"
require "open3"
require "time"

COPILOT_LOGIN = /\Acopilot-pull-request-reviewer/
INTERVAL_SEC = 30

def fetch_reviews(repo, number)
  stdout, stderr, status = Open3.capture3(
    "gh", "api", "--paginate", "--slurp", "repos/#{repo}/pulls/#{number}/reviews"
  )
  abort "gh api error: #{stderr}" unless status.success?

  JSON.parse(stdout).flatten
end

def copilot_review_after(reviews, since)
  reviews
    .select { |r| r.dig("user", "login")&.match?(COPILOT_LOGIN) }
    .select { |r| r["submitted_at"] && Time.iso8601(r["submitted_at"]) > since }
    .max_by { |r| r["submitted_at"] }
end

if ARGV.size < 3
  abort "Usage: ruby #{$PROGRAM_NAME} <owner/repo> <pr_number> <since> [timeout_sec]"
end

repo, number, since_arg, timeout_arg = ARGV
since = Time.iso8601(since_arg)
deadline = Time.now + Integer(timeout_arg || 1200)

loop do
  review = copilot_review_after(fetch_reviews(repo, number), since)
  if review
    puts JSON.pretty_generate(
      id: review["id"],
      state: review["state"],
      submitted_at: review["submitted_at"],
      body: review["body"]
    )
    exit 0
  end

  if Time.now >= deadline
    warn "timeout: Copilot review after #{since.iso8601} not found"
    exit 2
  end

  sleep INTERVAL_SEC
end
