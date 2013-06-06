An example plugin written in perl that illustrates use of the HTTP API to post metrics.

Prerequisites: JSON.pm (and its prerequisites), account @ New Relic

GUID: com.example.plugin.perl

TODO:
	doc/comment
	compression support
	reporting of account name if possible without API key
	handle long-term missing collector?
		

DONE:
	proxy support
	config file parsing
	basic metric posting
	metric preservation if collector post fails intermittently
