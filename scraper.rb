# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful
require 'scraperwiki'
require 'mechanize'
require_relative 'tryable'
require 'pry'

class Scraper
  attr_reader :agent, :base_page
  attr_accessor :current_page, :products

  PROTEINS = {

  }

  def initialize
    @agent = Mechanize.new
    @base_page = agent.get("http://www.intelmeal.ru/nutrition/food_category.php")
    @current_page = nil
    @products = []
  end

  def scrape(limit = -1)
    cat_links = base_page.search('.publish1 td a')
    cat_links[0..limit].each do |cat_link|
      parse_cat Mechanize::Page::Link.new(cat_link, agent, base_page)
      sleep 2
    end
  end

  def parse_cat(link)
    cat_page = link.click
    product_links = cat_page.search('.bb-list1 a')

    product_links.each do |prod_link|
      parse_product Mechanize::Page::Link.new(prod_link, agent, cat_page)
      sleep 0.5
    end
  end

  def parse_product(product_link)
    product_page = if product_link.is_a?(Mechanize::Page::Link)
                     product_link.click
                   else
                     agent.get(product_link)
                   end
    product = {}

    content = product_page.search('#content > div > div.publish1')
    product[:uri] = product_page.uri.to_s
    product[:name] = content[0].search('h1').last.text.gsub(/[[:space:]]{2,}/, ' ').chomp

    elements_table = content[4].search('div.fd0')

    [:general, :energy, :fats, :proteins, :carbohydrates, :vitamins, :minerals, :sterols, :other].each do |elem_block|
      product[elem_block] = _parse_common_table elements_table.shift
    end
  ensure
    pp product
  end

  private

    def _parse_common_table(table, res = {})
      data = table.element_children
      title_nodes = data.select do |child|
        klass = child.attributes['class']
        klass.text.match(/(?:fd1|fd4|fd3)(?:\s|$)/) if klass
      end
      group_nodes = data.select{|child| child.attributes.keys.include?('cd') }
      total = _parse_row title_nodes

      if (name = total[:name])
        res[name] = {}
        if group_nodes.size > 0
          res[name][:total] = total.reject{|k,v| k == :name } if total[:value]
        else
          res[name] = total.reject{|k,v| k == :name }
        end
      end

      group_nodes.each do |subtable|
        _parse_common_table subtable, (res[total[:name]] || res)
      end

      res
    end

    def _parse_row(row)
      name, val, rsp = row.map(&:text)
      val, metric = val.to_s.strip.chomp.split(/[[:space:]]/)
      val = nil if val.nil? || val.empty? || val == '~'
      name = _parse_name name
      Hash[ [:value, :metric, :rsp].zip([_parse_value(val), metric, rsp]) ].merge(name)
    end

    def _parse_name(name)
      m = name.to_s.match(/^(\d+\:\d+\w*)*(?:\s)*(?:(.+)|$)/)
      res = {name: m[2]}
      if m[1]
        res[:formula] = m[1]
      end
      res
    end

    def _parse_value(val)
      Integer(val) rescue Float(val) rescue val
    end

end

scraper = Scraper.new
if ARGV[0]
  scraper.parse_product(ARGV[0])
else
  scraper.scrape(1)
end

# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".
