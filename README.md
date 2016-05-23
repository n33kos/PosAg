# PosAg
PosAg (Position Aggregator) is a configurable scraper developed for aggregation of specific search URLs

# Dependencies
- Ruby >=v2.0.0
- Gems:
	- nokogiri

# Usage
1. Configure scraping sources by modifying ```config```:
> - ```base_url``` - The base url for your scrape source. This is used for rebuilding partial urls.
> - ```search_url``` - The specific search page you wish to scrape listings from.
> - ```entry_css_path``` - The CSS selector for indivitual entries. All other paths are relative to this path.
> - ```url_css_path``` - The CSS selector for the full listing URL relative to entry_css_path
> - ```title_css_path``` - The CSS selector for the listing title relative to entry_css_path
> - ```summary_css_path``` - The CSS selector for the listing summary relative to entry_css_path
> - ```desc_css_path``` - The CSS selector for the full listing description. PosAg will search for this selector within the markup of the detected full listing URL. This is NOT relative to entry_css_path like the other selectors.
> - ```employer_css_path``` - The CSS selector for the listing employer relative to entry_css_path
> - ```location_css_path``` - The CSS selector for the listing location relative to entry_css_path
> - ```date_posted_css_path``` - The CSS selector for the listing post date relative to entry_css_path

2. Run ```ruby posag.rb```
3. PosAg will parse the sources to the best of its ability and generate .csv and .html files containing the results.