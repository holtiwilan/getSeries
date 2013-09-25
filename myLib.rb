#!/usr/bin/ruby
############################################################################
# Needed gems
# mail - gem install mail
#
# config.yml is needed in same folder
############################################################################
require 'rubygems'
require 'yaml'
require 'rbconfig'
require 'csv'
require 'logger'
require 'mail'
require 'fileutils'

$t=Time.now

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

#Sended Mails
def sendMail(sReceiver, sSubject, sBody ,sFile)
	log_info "Schicke Mail an #{sReceiver} mit Betreff #{sSubject}"
	Mail.defaults do
	  delivery_method :smtp, { :address   => $cnf['mail']['server'],
							   :port      => $cnf['mail']['port'],
							   :domain    => $cnf['mail']['domain'],
							   :user_name => $cnf['mail']['user'],
							   :password  => $cnf['mail']['password'],
							   :authentication => $cnf['mail']['authentication'],
							   :enable_starttls_auto => $cnf['mail']['enable_starttls_auto'] }
	end

	mail = Mail.deliver do
	  to sReceiver
	  from $cnf['mail']['from']
	  subject sSubject
	  text_part do
		body sBody
	  end
	  html_part do
		content_type 'text/html; charset=UTF-8'
		body sBody
	  end
	  if !isNullOrEmpty(sFile)
	  	add_file sFile
	  end
	end
end

#erzeugt einen Logger
# es wird der ename des Scripts �bergeben
def createLogger(sScript)
	$sScript = sScript.gsub('.rb','')
	$log = Logger.new($cnf['logdir'] + $sScript + "_" + $t.strftime("%Y%m%d")+'.txt') #Logfile
	createLogger = $log
end

#Erzeugt einen Info Logeintrag und sendet ggf. einen Push an die Pebble
def log_info(sText, bPebble = false)
	$log.info sText
	if bPebble
		pushToPebble($sScript, sText)
	end
end

#Erzeugt einen Error Logeintrag und sendet ggf. einen Push an die Pebble
def log_error(sText, bPebble = true)
	$log.error sText
	if bPebble
		pushToPebble($sScript, sText)
	end
end

#Erzeugt einen Debug Logeintrag und sendet ggf. einen Push an die Pebble
def log_debug(sText, bPebble = false)
	$log.debug sText
	if bPebble
		pushToPebble($sScript, sText)
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
	log_info "starting pyloadCore"
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
		  log_info "pyloadCore is running with pid #{sPID}"
		end
	else
		# Hier m�ssen sich die Windowsuser was �berlegen
	end
	isPyloadRunning = bIsRunning
end

#Pr�fet, ob ein Verzeichnis existert und legt dieses an, wenn nciht vorhanden
def checkDir(sPath)
	checkDir = false
	if File.exists?(sPath) && File.directory?(sPath)
	 	log_info "Director #{sPath} exist, nothing to do here"
  	checkDir = true
	else
  	sPath = "\"" + sPath + "\""
  	log_info "Director #{sPath} does not exist, will create it"
  	sCMD = "mkdir -p #{sPath}"
		p sCMD
		if system(sCMD)
			checkDir = true
			log_info "Director #{sPath} created!"
		else
			checkDir = false
			log_error "Director #{sPath} creation failed!"
		end
	end
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

# �berpr�ft, ob der String in dem Array vohanden ist
def isInArray(aArray, sText)
	isInArray = aArray.include?(sText)
end


# config laden
def loadConfig()
	if getOS() == "MAC_OS_X" || getOS() == "Linux" || getOS() == "Solaris"
		fn = File.dirname(File.expand_path(__FILE__)) + '/config.yml'
	else
		fn = File.dirname(File.expand_path(__FILE__)) + '\\config.yml'
	end
	loadConfig = YAML::load(File.open(fn))
end

#l�d ein (csv) file in ein Array
def fileToArray(sFile,sSeparator)
	fileToArray = CSV.read(sFile)
end

#schreibt ein Objekt in eine Datei
def objectToFile(oObject, sFile)
	File.open(sFile, 'w') {|f| f.write(Marshal.dump(oObject)) }
end

#liest ein Objekt aus einer Datei
def objectFromFile(sFile)
	objectFromFile = Marshal.load(File.read(sFile))
end

$cnf = loadConfig() #config laden
