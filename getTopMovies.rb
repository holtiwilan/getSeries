#!/usr/bin/ruby

############################################################################
# Needed gems
# nokogiri - gem install nokogiri
# logger - gem install logger
#
# myLib.rb is needed in same folder
# config.yml is needed in same folder
############################################################################

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'find'
require 'ostruct'
require "#{File.dirname(__FILE__)}/myLib.rb"


sHoster = ["Uploaded", "uploaded"] #Liste der Hoster, mit denen geladen werden soll
createLogger(File.basename(__FILE__)) #Logfile
sBaseurl = $cnf['getTopMovies']['baseurl']  #URL zum Suchen nach den Serien
sMovieFile = $cnf['getTopMovies']['moviefile']#CSV Datei mit den Filemn, die schon geladen wurden
$sUsenetURL = $cnf['getTopMovies']['usenetlink']#hiermit können die Usenet Links identifiziert werden

# Prüft, ob der Link zu einem OCH geht, oder auf das Usenet referenziert
def isUsenet(sLink)
	hosterURL = ''
	bUsenet = true
	sResult = Nokogiri::HTML(open(sLink))
	sResult.css('div.eintrag2 a').each do |sDownLink|
		if !sDownLink['href'].include?($sUsenetURL)
			if hosterURL == sDownLink['href']
				bUsenet = true
			else
				bUsenet = false
			end
			hosterURL = sDownLink['href']
		end
	end
	isUsenet = bUsenet
end

# übergibt den gefundenen Link an pyload
def downloadMovie(sLink, sSearch, sHoster)
	bOK = false
	sCMD = $cnf['pyloadlient']
	begin
		if (!sLink.nil? && sLink.include?('http'))
			sCMD = sCMD + " add " + sSearch
			if !isUsenet(sLink)
				sResult = Nokogiri::HTML(open(sLink))
				sResult.css('div.eintrag2 a').each do |sDownLink|
					#p sDownLink
					sHoster.each do |h|
						if sDownLink.content.include?(h) && !sDownLink['href'].include?($sUsenetURL)    
							sCMD = sCMD + " " + sDownLink['href']
							log_info("Found #{sSearch} with Link #{sDownLink['href']}", true)
						end
					end
				end
			else
				log_info("Skipping Usenet Links")
			end
		end
		if sCMD.include?("http")
			system(sCMD)
			bOK = true		
		else
			bOK = false
		end
	rescue => e
		log_error(e.message, true)
	end
	downloadMovie = bOK
end

# Schaut nach den TopReleases und läd ggf. noch nicht geladene Filme runter
def getTopMovieList(sLink, sHoster, sMovieFile)
		if (!sLink.nil? && sLink.include?('http'))
				sResult = Nokogiri::HTML(open(sLink))
				sResult.css('div.beitrag2 h1 a').each do |sTopMovie|
					sTopMovieName = sTopMovie.content
					sURL = sTopMovie['href']
					log_info "Checking state for #{sTopMovieName}"
					if isInFile(sMovieFile, sTopMovie.content.to_s)
						log_info "#{sTopMovieName} was downloaded before"
					else
						log_info "trying to Download #{sTopMovieName}"
						if sLink != ''
							if downloadMovie(sURL, sTopMovieName, sHoster)
								writeMovieFile(sMovieFile, sTopMovieName)
							end
						end
					end
				end
		end
end

# fügt geladene Filme der Textdatei hinzu, in der die schon geladenen Filme gespeichert werden
def writeMovieFile(file, sMovie)
  begin
  	if getOS() == "MAC_OS_X" || getOS() == "Linux"
  		system("echo \"#{sMovie}\" >> #{file}")
  	else
			# Hier müssen sich die Windowsuser was überlegen
	  end
  rescue => e
    log_error(e.message, true)
  end  
end


#Main
getTopMovieList($cnf['getTopMovies']['topreleaseurl'], sHoster, sMovieFile)
