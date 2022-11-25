#!/usr/bin/env ruby

require "open-uri"
require "nokogiri"
require "yaml"

# https://my.sma-service.com/s/article/Sunny-Tripower-Manuals?language=en_US
URLS = %w[
  https://manuals.sma.de/STPxxx60/en-US/8016917899.html
  https://manuals.sma.de/STP50-40/en-US/391460235.html
  https://manuals.sma.de/STP8-10-3AV-40/en-US/391460235.html
  https://manuals.sma.de/STPxx-3av-40-BE/en-US/391460235.html
  https://manuals.sma.de/STPTL-JP-30/en-US/391458315.html
  https://manuals.sma.de/STPTL-30/en-US/391460235.html
]

# Parse and expand codes into a list: `1-3` -> `1, 2, 3`
def parse_codes(code)
  return code.to_i if code.match(/^[0-9]+$/)

  _, from, _, to = code.match(/([0-9]+)[\s\u00A0]*(-|to|…)\s*([0-9]+)/).to_a
  if from && to
    from.to_i.upto(to.to_i).to_a
  else
    raise ArgumentError, "Unable to parse code: `#{code}`"
  end
end

# Parse manual HTML into alerts database
def process_doc(html)
  database = {}

  doc = Nokogiri::HTML(html)
  doc.css(".table_standard tr").each do |row|
    codes = row.children[0].text.strip.lines.map(&:strip)
    next if codes.first[/Event/]

    codes = codes.flat_map { parse_codes(_1) }
    next if codes.size > 10

    info, measures_str = row.children[1].text.strip.split("Corrective measures:").map(&:strip)
    title, description = info.lines.map(&:strip)
    measures = measures_str.lines.map(&:strip) if measures_str

    codes.each do |code|
      database[code] = {
        title: title,
        description: description,
        measures: measures
      }
    end
  end

  database
end

# Defines which alert description is better
def winning_description(data1, data2)
  [data1, data2]
    .sort_by do |data|
      [
        data[:measures].to_a.size,
        data[:description].to_s.size,
        data[:title].to_s.size
      ]
    end
    .last
end

# Generates overall alerts database
def generate_database
  summary = {}

  URLS.each do |url|
    html = URI.open(url).read
    database = process_doc(html)

    database.each do |code, data|
      if summary[code] && summary[code] != data
        summary[code] = winning_description(summary[code], data)
      else
        summary[code] = data
      end
    end
  end

  summary
end

# Generates alerts suitable for YAML generation
def generate_alerts(database)
  alerts = {}

  database.each do |code, data|
    alert = {
      "display_name" => data[:title].gsub(/\s*\([0-9]+\)/, ""),
      "severity" => "error"
    }

    if data[:description] || data[:measures]
      measures =
        if data[:measures]
          if data[:measures].size == 1
            data[:measures].first
          else
            <<~MEASURES
              Corrective measures:
              #{data[:measures].map { "- #{_1}" }.join("\n")}
            MEASURES
          end
        end

      alert["description"] = [data[:description], measures].compact.join("\n")
    end

    alerts["e#{code}"] = alert
  end

  alerts
end

alerts = generate_alerts(generate_database)
puts YAML.dump(alerts).gsub("\u00A0", " ")
