#!/usr/bin/env ruby
# frozen_string_literal: true
#
# スカイリム日英対訳表 (HTML) から英語→日本語のグロッサリ TSV を抽出する。
#
#   ruby extract-glossary.rb スカイリム日英対訳表_250627.html > skyrim-full.tsv
#
# 各行 <tr> は 4 セル構成で 2 列目=英語 / 3 列目=日本語。1 列目はカテゴリ名や
# ID 番号。英語列にラテン文字、日本語列に仮名/漢字を含む行だけを採用する。
# 出力はグロッサリ機能がそのまま読める `English<TAB>日本語` 形式。

require 'cgi'

path = ARGV[0]
abort "usage: ruby extract-glossary.rb <html>" unless path
html = File.read(path, encoding: 'bom|utf-8')

def clean(cell)
  # タグ除去 → 実体参照復元 → 空白正規化
  text = cell.gsub(/<[^>]*>/, ' ')
  text = CGI.unescapeHTML(text)
  text.gsub(/[[:space:]]+/, ' ').strip
end

HAS_LATIN = /[A-Za-z]/
HAS_JA = /[\p{Hiragana}\p{Katakana}\p{Han}]/

seen = {}        # English => 日本語 (先頭優先)
conflicts = 0
rows = 0

# <tr>...</tr> を改行またぎで走査
html.scan(/<tr\b[^>]*>(.*?)<\/tr>/im) do |(body)|
  rows += 1
  cells = body.scan(/<td\b[^>]*>(.*?)<\/td>/im).map { |(c)| clean(c) }
  next if cells.length < 3

  en = cells[1]
  ja = cells[2]
  next if en.empty? || ja.empty?
  next unless en.match?(HAS_LATIN) && ja.match?(HAS_JA)
  next if en == ja

  if seen.key?(en)
    conflicts += 1 if seen[en] != ja
    next
  end
  seen[en] = ja
end

seen.each { |en, ja| puts "#{en}\t#{ja}" }

warn "rows scanned: #{rows}"
warn "entries: #{seen.size}"
warn "conflicts skipped (same EN, different JA): #{conflicts}"
