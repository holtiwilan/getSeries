#!/usr/bin/ruby
require 'yaml'
require 'rbconfig'

# erzeugt eine Pushbenachrichtigung per Pushover
# der Dienst ist kostenfrei http://www.pushover.net
def pushToPebble(sApp, sText)
	sToken = ""
	if isNullOrEmpty(sApp)
		sApp = "misc"
	end
	sToken = $cnf['pebble']['token'][sApp]
	sUser = $cnf['pebble']['user']
	if !isNullOrEmpty(sToken) && !isNullOrEmpty(sText)
		if getOS() == "MAC_OS_X" || getOS() == "Linux"
			system("curl -s -F \"token=#{sToken}\" -F \"user=#{sUser}\" -F \"message=#{sText}\" https://api.pushover.net/1/messages.json")
		else
			# Hier m�ssen sich die Windowsuser was �berlegen
	  end
  end
end

#Funktion zum herausfinden, auf welchem Betriebssystem das Script l�uft.
def getOS()
	include Config
	sOS = "unknown"
	case CONFIG['host_os']
	  when /mswin|windows/i
	    sOS = "Windows"
	  when /linux|arch/i
	    sOS = "Linux"
	  when /sunos|solaris/i
	    sOS = "Solaris"
	  when /darwin/i
	    sOS = "MAC_OS_X"
	  else
	    # whatever
	end
	getOS = sOS
end

# Existiert die Datei?
# Aus stabilit�tsgr�nden f�r MACOS mit commandline umgesetzt
def fileExists(sFile)
	if getOS() == "MAC_OS_X" || getOS() == "Linux"
		fileExists = system("ls #{sFile} > /dev/null 2>&1")
	else
		fileExists = File.exist?(sFile)
	end
end

# Ist die Datei leer?
# Aus stabilit�tsgr�nden f�r MACOS mit commandline umgesetzt
def fileIsEmpty(sFile)
	if getOS() == "MAC_OS_X" || getOS() == "Linux"
		fileIsEmpty = system("[ -s #{sFile} ]")
	else
		fileIsEmpty = File.zero?(sFile)
	end
end

# Sorgt daf�r, das Plex die Section refreshed um die neuen inhalte anzuzeigen.
def refreshPlex(sSection)
	iSection = 0
	if sSection.is_a?(Numeric)
		iSection = sSection.to_i
	else
		iSection = $cnf['plex']['section'][sSection]
	end
	if !isNullOrEmpty(iSection) && iSection != 0
		system("#{$cnf['plex']['pyloadstart']} #{iSection}")
	else
		p "#{sSection} is an unkown Section in Plex"
	end
end

#(re)startet pyLoad.
# ben�tigt ein shell oder batchscript (siehe config.yml)
def startPyLoad()
	$log.info "starting pyloadCore"
	system($cnf['pyloadstart'])
end

#�berpr�fung, ob pyLoad l�uft.
# Windosnutzer m�ssen hier basteln
def isPyloadRunning()
	bIsRunning = false
	if getOS() == "MAC_OS_X" || getOS() == "Linux"
		sPID = `ps aux | grep pyLoadCore.py |grep -v grep | awk '{ print $2 }'`.gsub("\n","")
		#p sPID
		if sPID == ""
		  bIsRunning = false
		  $log.error "pyloadCore is not running"
		else
		  bIsRunning = true
		  $log.info "pyloadCore is running with pid #{sPID}"
		end
	else
		# Hier m�ssen sich die Windowsuser was �berlegen
	end
	isPyloadRunning = bIsRunning
end

# �berpr�ft, ob in pyLoad fehlgeschlagene Downloads vorhanden sind.
# startet pyLoad neu, wenn true
def checkForFailedDownloads()
	bFailed = system("#{$cnf['pyloadlient']} queue |grep fehlgeschlagen")
	if bFailed
		system($cnf['pyloadstart'])
		pushToPebble("", "Fehlgeschlagene Downloads, restarte pyLoad")
	end
end

# �berpr�ft, ob der String nil oder leer ist
def isNullOrEmpty(sText)
	bisNullOrEmpty = false
	if sText.to_s.strip.length == 0
		bisNullOrEmpty = true
	else
		bisNullOrEmpty = false
	end
	isNullOrEmpty = bisNullOrEmpty
end

# �berpr�ft, ob der String in der Datei vohanden ist
def isInFile(sFile, sText)
	bIsInFile = false
	if !isNullOrEmpty(sText)
		if File.open(sFile).lines.any?{|line| line.include?(sText)}
  		bIsInFile = true
		end
	else
		bIsInFile = false
	end
	isInFile = bIsInFile
end

# config laden
def loadConfig()
	fn = File.dirname(File.expand_path(__FILE__)) + '/config.yml'
	loadConfig = YAML::load(File.open(fn))
end


$cnf = loadConfig() #config laden