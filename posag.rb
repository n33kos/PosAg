require 'Nokogiri'
require 'open-uri'
require 'openssl'
require 'csv'
require 'json'

#---------------Classes--------------
class ScrapeSource
	attr_accessor :base_url, :search_url, :entry_css_path, :url_css_path, :title_css_path, :summary_css_path, :desc_css_path
	@base_url = ""
	@search_url = ""
	@entry_css_path = ""
	@url_css_path = ""
	@title_css_path = ""
	@summary_css_path = ""
	@desc_css_path = ""
end

class PositionListing
	attr_accessor :url, :title, :summary, :desc, :source
	@url = ""
	@title = ""
	@summary = ""
	@desc = ""
	@source = ""
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

#-------------Sources-----------------
sources = []

stackoverflow = ScrapeSource.new
stackoverflow.base_url = "http://stackoverflow.com"
stackoverflow.search_url = "http://stackoverflow.com/jobs?searchTerm=web+developer&location=denver&range=50&distanceUnits=Miles&sort=p"
stackoverflow.entry_css_path = ".listResults.jobs .-job"
stackoverflow.url_css_path = ".job-link"
stackoverflow.title_css_path = ".job-link"
stackoverflow.summary_css_path = "p.text._muted"
stackoverflow.desc_css_path = ".jobdetail"
sources.push(stackoverflow)

careerjet = ScrapeSource.new
careerjet.base_url = "http://www.careerjet.com"
careerjet.search_url = "http://www.careerjet.com/search/jobs?s=Web+Developer&l=Denver"
careerjet.entry_css_path = "#heart .job"
careerjet.url_css_path = ".title_compact"
careerjet.title_css_path = ".title_compact"
careerjet.summary_css_path = ".advertise_compact"
careerjet.desc_css_path = ""
sources.push(careerjet)

simplyhired = ScrapeSource.new
simplyhired.base_url = "http://www.simplyhired.com"
simplyhired.search_url = "http://www.simplyhired.com/search?q=web+developer&l=denver,+co&ws=50"
simplyhired.entry_css_path = ".js-jobs .js-job"
simplyhired.url_css_path = ".js-job-link"
simplyhired.title_css_path = ".js-job-link h2"
simplyhired.summary_css_path = ".serp-snippet"
simplyhired.desc_css_path = ".jp-description"
sources.push(simplyhired)

indeed = ScrapeSource.new
indeed.base_url = "http://www.indeed.com"
indeed.search_url = "http://www.indeed.com/q-Web-Developer-l-Denver,-CO-jobs.html"
indeed.entry_css_path = "#resultsCol .result"
indeed.url_css_path = ".jobtitle a"
indeed.title_css_path = ".jobtitle a"
indeed.summary_css_path = ".summary"
indeed.desc_css_path = "#job_summary"
sources.push(indeed)

craigslist = ScrapeSource.new
craigslist.base_url = "http://denver.craigslist.org"
craigslist.search_url = "http://denver.craigslist.org/search/web"
craigslist.entry_css_path = ".rows .row"
craigslist.url_css_path = ".hdrlnk"
craigslist.title_css_path = ".hdrlnk span"
craigslist.summary_css_path = ".hdrlnk span"
craigslist.desc_css_path = "section#postingbody"
sources.push(craigslist)

linkedin = ScrapeSource.new
linkedin.base_url = "https://www.linkedin.com"
linkedin.search_url = "https://www.linkedin.com/jobs/search?keywords=Web+Developer&locationId=us:34&orig=JSERP&start=25&count=25&trk=jobs_jserp_pagination_2"
linkedin.entry_css_path = ".job-listing"
linkedin.url_css_path = ".job-title-link"
linkedin.title_css_path = ".job-title-text"
linkedin.summary_css_path = ".job-description"
linkedin.desc_css_path = "code#jobDescriptionModule/comment()"
sources.push(linkedin)

#-------------Aggregate----------------
listings = []
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
sources.each do |source|
	page = Nokogiri::HTML(open(source.search_url))
	puts "-------------Reading Listings From "+source.base_url+"--------------"
	page.css(source.entry_css_path).each do |extract|
		listing = PositionListing.new
		begin
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
			listing.title = extract.css(source.title_css_path)[0].content
			listing.summary = extract.css(source.summary_css_path)[0].content
			listing.source = source.search_url
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
		begin
			follow_page = Nokogiri::XML(open(listing.url.to_s))
			listing.desc = follow_page.css(source.desc_css_path)[0].content
			puts "Parsed description for " + listing.title
		rescue
			puts "Unable To Parse Extended Description for " + listing.title
		end
	end
end
puts "\nAggregated "+listings.length.to_s+" Listings."

#-----------------Generate CSV------------------------------
output_file_name = "aggregated"+Time.now.strftime('%Y-%m-%d_%H%M%S').to_s
CSV.open(output_file_name+".csv", 'w') do |csv|
  csv << ["url", "title", "summary", "desc", "source"]
  listings.each do |listing|
  	csv << [listing.url.to_s, listing.title.to_s, listing.summary.to_s, listing.desc.to_s, listing.source.to_s]
  end
end
puts "\nGenerated "+output_file_name+".csv"

#-----------------Generate HTML-----------------------------
aggregated = File.open(output_file_name+".html", 'w')
aggregated.puts '<html><body style="width:80%;margin: 0 auto;">'
listings.each do |listing|
	aggregated.puts '<div class="listing">'
	aggregated.puts '<h3 style="margin-bottom:0;"><a href="'+listing.url.to_s+'">'+listing.title.to_s+'</a></h3>'
	aggregated.puts '<span style="font-size:10px;"><a href="'+listing.source.to_s+'">'+listing.source.to_s.truncate(250, omission: '...')+'</a></span>'
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
aggregated.close
puts "\nGenerated "+output_file_name+".html"