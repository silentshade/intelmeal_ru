# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful
require 'scraperwiki'
require 'mechanize'

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

    [:general, :energy, :fats, :proteins, :carbohydrates].each do |elem_block|
      product[elem_block] = send("_parse_#{elem_block}", elements_table.shift)
    end
  ensure
    pp product
  end

  private

    def _parse_general(table)
      Hash[[:water,
            :carbohydrates,
            :fibers,
            :fats,
            :proteins,
            :alcohol,
            :cholesterol,
            :ashes].zip (7..14).map{|i| _parse_row(table.element_children[i].element_children) rescue nil }]
    end

    def _parse_energy(table)
      data = table.element_children[-1].element_children
      total = _parse_row(data[0..2])
      total.delete(:name)
      res = { total: total }
      Hash[[:from_carbohydrates,
            :from_fats,
            :from_proteins,
            :from_alcohol].zip(data[3..-1].map do |el|
                                parsed_row = _parse_row(el.element_children)
                                parsed_row.delete(:name)
                                parsed_row
                              end)].merge(res)
    end

    def _parse_fats(table)
      _parse_fats_subgroup table.element_children[6]
    end

    def _parse_fats_subgroup(table)
      data = table.element_children
      total = _parse_row(data[0..2])
      name = total.delete(:name)
      res = {total: total}
      if name == 'Жиры:'
        {saturated: 3, monounsaturated: 4, polyunsaturated: 5}.each do |key, index|
          res[key] = _parse_fats_subgroup(data[index])
        end
      else
        data[4..-1].each_with_index do |row, i|
          res[i] = _parse_row(row.element_children)
        end
      end
      res
    end

    def _parse_proteins(table)
      _parse_proteins_subgroup table.element_children[6]
    end

    def _parse_proteins_subgroup(table)
      data = table.element_children
      total = _parse_row(data[0..2])
      name = total.delete(:name)
      res = {}
      if name == 'Белки:'
        res[:total] = total
        {indispensable: 3, dispensable: 4}.each do |key, index|
          res[key] = _parse_proteins_subgroup(data[index])
        end
      elsif name == ''
      else
        data[4..-1].each_with_index do |row, i|
          res[i] = _parse_row(row.element_children)
        end
      end
      res
    end

    def _parse_carbohydrates(table)
      _parse_cb_subgroup table.element_children[4]
    end

    def _parse_cb_subgroup(table)
      data = table.element_children
      total = _parse_row(data[0..2])
      name = total.delete(:name)
      res = {total: total}
      if name == 'Углеводы всего:'
        {fiber: 3, amylum: 4}.each do |key, index|
          res[key] = _parse_row(data[index].element_children)
        end
        res[:sugar] = _parse_cb_subgroup(data[5])
      else
        data[4..-1].each_with_index do |row, i|
          res[i] = _parse_row(row.element_children)
        end
      end
      res
    end

    def _parse_row(row)
      name, val, rsp = row.map(&:text)
      val, metric = val.to_s.strip.chomp.split(/[[:space:]]/)
      val = nil if val.nil? || val.empty?
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
