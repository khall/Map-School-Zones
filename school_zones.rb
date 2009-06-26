# Small script to utilize public school list from http://www.cde.ca.gov/ds/si/ds/pubschls.asp and to figure out a rough idea of where the school zones are
# It should be noted that the polygons created are squares and that this data could very well be wrong.
#
# You may run this script via: "ruby school_zones.rb pubschls.txt"

require 'rubygems'
require 'geokit'
require 'ruby-debug'
require 'json'

def parse_school_file(file)
  puts "Parsing file"
  school_file = File.new(file, 'r')
  open_schools = []
  while !school_file.eof? do
    school = school_file.readline
    if school.match(/^\d+?;OPEN/)
      parsed_school = school.split(/\s*;/)
      open_schools << {:lat     => parsed_school[28],
                       :long    => parsed_school[29],
                       :address => parsed_school[5],
                       :city    => parsed_school[6],
                       :state   => parsed_school[8],
                       :name    => parsed_school[4],
                       :type    => parsed_school[14]}
    end
  end
  open_schools
end

def lookup_geo_location(schools)
  puts "Looking up missing geo locations"
  schools.each do |s|
    if s[:lat].empty? || s[:long].empty?
      putc "."
      geo_data = Geokit::Geocoders::YahooGeocoder.geocode "#{s[:address]}, #{s[:city]}, #{s[:state]}"
      s[:lat] = geo_data.lat
      s[:long] = geo_data.lng
      s[:geodata] = geo_data
    end
  end
  putc "\n"
  schools
end

def construct_polygons(schools)
  puts "Constructing polygons"
  polys = []
  schools.each do |s|
    geo = Geokit::GeoLoc.new(:lat => s[:lat], :lng => s[:long])
    ne = geo.endpoint(45, 0.2)
    se = geo.endpoint(135, 0.2)
    sw = geo.endpoint(225, 0.2)
    nw = geo.endpoint(315, 0.2)
    polys << {:name => s[:name], :points => [{:lat => ne.lat, :lng => ne.lng},
                                             {:lat => se.lat, :lng => se.lng},
                                             {:lat => sw.lat, :lng => sw.lng},
                                             {:lat => nw.lat, :lng => nw.lng}]}
  end
  polys
end

if ARGV[0].empty?
  puts "ruby school_zones.rb <school file>"
  exit
end

schools = parse_school_file ARGV[0]
schools.reject!{|s| ['ADULT ED', 'JUVENILE HALL'].include? s[:type]}
schools = lookup_geo_location schools
polys = construct_polygons schools

polys.each do |p|
  begin
    puts p.to_json
  rescue => e
    p[:name].gsub!(/\\\d+/, "_")
    puts p.to_json
  end
end
