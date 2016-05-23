require 'Nokogiri'
require 'open-uri'
require 'openssl'
require 'csv'
require 'json'
require 'yaml'

#---------------Classes--------------
class ScrapeSource
	attr_accessor :base_url, :search_url, :entry_css_path, :url_css_path, :title_css_path, :summary_css_path, :desc_css_path, :employer_css_path, :location_css_path, :date_posted_css_path
	@base_url = ""
	@search_url = ""
	@entry_css_path = ""
	@url_css_path = ""
	@title_css_path = ""
	@summary_css_path = ""
	@desc_css_path = ""
	@employer_css_path = ""
	@location_css_path = ""
	@date_posted_css_path = ""
end

class PositionListing
	attr_accessor :url, :title, :summary, :desc, :employer, :location, :source, :date_posted
	@url = ""
	@title = ""
	@summary = ""
	@desc = ""
	@employer = ""
	@location = ""
	@source = ""
	@date_posted = ""
end

#------------Functions----------------
class String
	def truncate(truncate_at, options = {})
	  return dup unless length > truncate_at
	  options[:omission] ||= '...'
	  length_with_room_for_omission = truncate_at - options[:omission].length
	  stop =        if options[:separator]
	      rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
	    else
	      length_with_room_for_omission
	    end

	  "#{self[0...stop]}#{options[:omission]}"
	end
end

def define_sources
	sources = []
	yaml_sources = YAML.load_file("config")
	yaml_sources.each do |source|
		new_source = ScrapeSource.new
		new_source.base_url = source[1][:base_url].to_s
		new_source.search_url = source[1][:search_url].to_s
		new_source.entry_css_path = source[1][:entry_css_path].to_s
		new_source.url_css_path = source[1][:url_css_path].to_s
		new_source.title_css_path = source[1][:title_css_path].to_s
		new_source.summary_css_path = source[1][:summary_css_path].to_s
		new_source.desc_css_path = source[1][:desc_css_path].to_s
		new_source.employer_css_path = source[1][:employer_css_path].to_s
		new_source.location_css_path = source[1][:location_css_path].to_s
		new_source.date_posted_css_path = source[1][:date_posted_css_path].to_s
		sources.push(new_source)
	end
	return sources
end

#initialize constant for ssl connections
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE 
def aggregate_listings sources
	listings = []
	sources.each do |source|
		#Parse Page
		page = Nokogiri::HTML(open(source.search_url))
		puts "-------------Reading Listings From "+source.base_url+"--------------"
		#for each identified entry
		page.css(source.entry_css_path).each do |extract|
			#init new PositionListing object
			listing = PositionListing.new
			begin
				#Process and add URL to listing object
				prep_url = extract.css(source.url_css_path)[0]['href'].to_s
				if prep_url.include? "//"
					url = prep_url
				else
					if prep_url.include? source.base_url
						url = prep_url
					else
						url = source.base_url+prep_url
					end
				end
				listing.url = url

				#Search for other data points and add them to listing object
				if !source.search_url.empty?
					listing.source = source.search_url
				end
				if !source.title_css_path.empty?
					listing.title = extract.css(source.title_css_path)[0].content
				end
				if !source.summary_css_path.empty?
					listing.summary = extract.css(source.summary_css_path)[0].content
				end
				if !source.employer_css_path.empty?
					listing.employer = extract.css(source.employer_css_path)[0].content
				end
				if !source.location_css_path.empty?
					listing.location = extract.css(source.location_css_path)[0].content
				end
				if !source.date_posted_css_path.empty?
					listing.date_posted = extract.css(source.date_posted_css_path)[0].content
				end

				#Add listing to listings array
				if url.include? source.base_url
					listings.push(listing)
				end
				puts "Parsed Data From Node "+source.entry_css_path
			rescue
				puts "Unable to recognize node."
			end
		end
		puts "-------------Reading Descriptions From "+source.base_url+"--------------"
		listings.each do |listing|
			#Attempt to follow url for a full description of the listing
			begin
				follow_page = Nokogiri::XML(open(listing.url.to_s))
				listing.desc = follow_page.css(source.desc_css_path)[0].content
				puts "Parsed Extended Description For " + listing.title
			rescue
				puts "Unable To Parse Extended Description For " + listing.title
			end
		end
	end
	puts "\nAggregated "+listings.length.to_s+" Listings."
	return listings
end

def generate_csv listings
	#prep filename
	output_file_name = "aggregated"+Time.now.strftime('%Y-%m-%d_%H%M%S').to_s
	#open file for writing, using a do end will autoclose the file
	CSV.open(output_file_name+".csv", 'w') do |csv|
		#add top row
		csv << ["url", "title", "summary", "desc", "employer", "location", "source", "date_posted"]
		#Add each listing as rows
		listings.each do |listing|
			csv << [listing.url.to_s, listing.title.to_s, listing.summary.to_s, listing.desc.to_s, listing.employer.to_s, listing.location.to_s, listing.source.to_s, listing.date_posted.to_s]
		end
	end
	puts "\nGenerated "+output_file_name+".csv"
end

def generate_html listings
	#prep filename
	output_file_name = "aggregated"+Time.now.strftime('%Y-%m-%d_%H%M%S').to_s
	#Open file for writing
	aggregated = File.open(output_file_name+".html", 'w')
	aggregated.puts '<html><body style="width:80%;margin: 0 auto;">'
	listings.each do |listing|
		aggregated.puts '<div class="listing">'
		aggregated.puts '<h3 style="margin-bottom:0;"><a href="'+listing.url.to_s+'">'+listing.title.to_s+'</a></h3>'
		aggregated.puts '<span style="font-size:10px;"><a href="'+listing.source.to_s+'">'+listing.source.to_s.truncate(50, omission: '...')+'</a></span>'
		aggregated.puts '<div style="font-size:12px;color:green;">'+listing.employer.to_s+' - '+listing.location.to_s+' - '+listing.date_posted.to_s+'</div>'
		if !listing.summary.empty?
			aggregated.puts '<div class="description">'+listing.summary.to_s+'</div>'
		else	
			if listing.url.to_s.include? "linkedin"
				aggregated.puts '<div class="description">'+JSON.parse(listing.desc.to_s)['description'].to_s.truncate(1500, omission: '...')+'</div>'
			else
				aggregated.puts '<div class="description">'+listing.desc.to_s.truncate(1500, omission: '...')+'</div>'
			end
		end
		aggregated.puts '</div>'
	end
	aggregated.puts '</body></html>'
	#close the file after writing
	aggregated.close
	puts "\nGenerated "+output_file_name+".html"
end

#---------------------Initialization--------------------
sources = define_sources
listings = aggregate_listings sources
generate_csv listings
generate_html listings