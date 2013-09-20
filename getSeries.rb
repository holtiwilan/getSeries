#!/usr/bin/ruby

############################################################################
# Needed gems
# nokogiri - gem install nokogiri
# logger - gem install logger
#
# myLib.rb is needed in same folder
# config.yml is needed in same folder
# searchfile must be configured in config.yml
############################################################################

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'ostruct'
require "#{File.dirname(__FILE__)}/myLib.rb"

sHoster = ["Uploaded", "uploaded"] #Liste der Hoster, mit denen geladen werden soll
createLogger(File.basename(__FILE__)) #Logfile
sBaseurl = $cnf['getSeries']['baseurl']  #URL zum Suchen nach den Serien
sSearchFile = $cnf['getSeries']['searchfile']#CSV Datei mit den Serien, die geladen werden sollen
$osSerie = OpenStruct.new #Hash zum vorhalten der Informationen zum Laden einer Folge
sSuffix = $cnf['getSeries']['searchSuffix'] #Suchsuffix, z.B. German+Dubbed für deutsche Folgen

#Funktion zum aktuallisieren der CSV Datei mit den Serien
def writeSeriesFile(file)
  begin
  	sNewLine = "#{$osSerie.sname};#{$osSerie.sseason};#{$osSerie.sepisode};#{$osSerie.squali};#{$osSerie.sattempts}"
    sCMD = "sed -i -e \"s/#{$sLine}/#{sNewLine}/g\" #{file}"
		system(sCMD)
  rescue => e
  	log_error("writeSeriesFile" + e.message, true)
  end  
end

#Funktion zum Hinzufügen des Downloads zu pyload
def downloadSeries(sLink, sSearch, sHoster)
	bOK = false
	sCMD = $cnf['pyloadlient']
	begin
		if (!sLink.nil? && sLink.include?('http'))
			sCMD = sCMD + " add " + sSearch
			sResult = Nokogiri::HTML(open(sLink))
			sResult.css('div.eintrag2 a').each do |sDownLink|
				sHoster.each do |h|
					if sDownLink.content.include?(h)    
						sCMD = sCMD + " " + sDownLink['href']
						log_info("Found #{sSearch} with Link #{sDownLink['href']}", true)
					end
				end
			end
		end
		if sCMD.include?("http")
			system(sCMD)
			bOK = true		
		else
			bOK = false
		end
	rescue => e
		log_error("downloadSeries" + e.message, true)
	end
	downloadSeries = bOK
end

#Sucht den Downloadlink
def getDownLink(sBaseurl, sSearch)
		sLinkXVID = ''
		sLink720p = ''
		sLink1080p = ''
		begin
			sSearchResult = Nokogiri::HTML(open(sBaseurl + sSearch))
			#Verschiedene Qualitäten Suchen
			sSearchResult.css('h1 a').each do |link|
				if link['href'].include?("xvid")
					sLinkXVID = link['href']
				end
				if link['href'].include?("720p")
					sLink720p = link['href']
				end
				if link['href'].include?("1080p")
					sLink1080p = link['href']
				end
			end
			# Links mit 1080p werden bevorzugt
			if sLink1080p != ''
				$osSerie.squali = '1080p'
				sLink = sLink1080p
				log_info "Getting #{sSearch} in 1080p"
			elsif sLink720p != ''
				$osSerie.squali = '720p'
				sLink = sLink720p
				log_info "Getting #{sSearch} in 720p"
			elsif sLinkXVID != ''
				# Wenn nur xvid Qualität gefunden wurde, wird nach dem 5, versuch eine bessere Quali zu finden, xvid geladen
				log_info "Found #{sSearch} only in xvid"
				log_info "Checking last found Quality for #{sSearch} in xVid"
				if $osSerie.squali == 'xvid'
					log_info "Last found Quality for #{sSearch} was xvid, checking allready tried attempts"
					log_info "Tried to find in better quality #{$osSerie.sattempts} times"
					if $osSerie.sattempts.to_i <= 5
						$osSerie.sattempts = ($osSerie.sattempts.to_i + 1)
						log_info "Rescheduling #{sSearch}"
						sLink = ''
					else
						log_info "This is the #{$osSerie.sattempts} try downloading #{sSearch} now in xvid"
						$osSerie.sattempts = "0"
						log_info "Setting Attempts to #{$osSerie.sattempts}"
						sLink = sLinkXVID
					end
				end
			end
			getDownLink = sLink
		rescue => e
			log_error("getDownLink" + e.message, true)
		end
end

#Funktion zum lesen der CSV Datei mit den Serien, die gesucht werden sollen
def readSeriesFile(sBaseurl, sSearchFile, sHoster)
		begin
			file = File.new(sSearchFile, "r")
			while (line = file.gets)
				if !line.match(/^#/) #Kommentare aus dem CSV nicht verarbeiten
					$sLine = line.gsub("\n","").split(";")
					$osSerie.sname = $sLine[0].gsub(" ",".").gsub("+",".")
					if $sLine[1] == "" || $sLine[1].nil?
						$osSerie.sseason = "01"
					else
						$osSerie.sseason = $sLine[1]
					end
					if $sLine[2] == "" || $sLine[2].nil?
						$osSerie.sepisode = "01"
					else
						$osSerie.sepisode = $sLine[2]
					end
					if $sLine[3] == "" || $sLine[3].nil?
						$osSerie.squali = $sQuali
					else
						$osSerie.squali = $sLine[3]
					end
					if $sLine[4] == "" || $sLine[4].nil?
						$osSerie.sattempts = 0
					else
						$osSerie.sattempts = $sLine[4]
					end
					$sLine = line.gsub("\n","")
					sSearch = "#{$osSerie.sname}.S#{$osSerie.sseason}E#{$osSerie.sepisode}#{$cnf['getSeries']['searchSuffix']}"
					sLink = getDownLink(sBaseurl, sSearch)
					#Vielleicht ist die aktuelle Staffel zu Ende, mal schauen ob die neue schon angefangen hat
					if sLink != ''
						if downloadSeries(sLink, sSearch, sHoster)
							$osSerie.sepisode = "%02d" % ($osSerie.sepisode.to_i + 1)
						else 
							if $osSerie.sepisode != "01"
								sNextSeason = "%02d" % ($osSerie.sseason.to_i + 1)
								sSearch = "#{$osSerie.sname}+S#{sNextSeason}E01#{$cnf['getSeries']['searchSuffix']}"
								sLink = getDownLink(sBaseurl, sSearch)
								if downloadSeries(sLink, sSearch, sHoster)
								  log_info "Next Season of #{sSeries} has started"
								  $osSerie.sseason = sNextSeason
									$osSerie.sepisode = "01"
								end
							end
						end
					end
					writeSeriesFile(sSearchFile)
				end
			end
		rescue IOError => e
			log_error("readSeriesFile" + e.message, true)
  	ensure
  		file.close unless file == nil
  	end 
end

#Main
begin
	readSeriesFile(sBaseurl, sSearchFile, sHoster)
rescue => e
	log_error("Main" + e.message, true)
end