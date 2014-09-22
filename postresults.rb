require 'rubygems'
require 'pp'
require 'json'
require 'date'
require 'logger'
require 'zip'
require 'net/http'
require 'uri'
require 'net/http/post/multipart'

require_relative 'OptimizationChecks'
require_relative 'optimizationClasses'

class Results

  attr_accessor :path, :pathHar, :id

  def initialize(nameIn, nameHar)
    @id = nameIn
    @path = "./public/results/#{nameIn}"
    @pathHar = nameHar
  end

  def get_video(zipfile, id)
    pp ("#{path}/#{id}0.webm")
    movie = FFMPEG::Movie.new("#{path}/#{id}0.webm")
    pp "ok movie loaded"
    duration = movie.duration
    if (duration > 3.5)
      step = 0.5
    else
      step = 0.1
    end
    pos = 0
    pos_movie = 0
    while (pos < duration) do
      if (pos_movie < 10)
        frameName = "frame_000#{pos_movie}.jpg"
      else
        frameName = "frame_00#{pos_movie}.jpg"
      end
      framePath = "#{path}/video_1/#{frameName}"
      pp framePath
      movie.screenshot(framePath, seek_time: pos)
      zipfile.add(frameName, framePath)
      pos += step
      pos_movie += 1
    end

  end

  def send(location, ip)
    zipfile_name = "#{path}/results.zip"
    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      zipfile.add('1_IEWTR.txt', "#{path}/1_IEWTR.txt")
      zipfile.add('1_IEWPG.txt', "#{path}/1_IEWPG.txt")
      zipfile.add('1_report.txt', "#{path}/1_report.txt")
      #get_video(zipfile, @id)
      zipfile.get_output_stream("myFile") { |os| os.write "myFile contains just this" }
    end
    pp "On va POST"
    pp "#{ip}/work/workdone.php"
    pp URI("#{ip}/work/workdone.php")
    pp zipfile_name

    url = URI.parse("#{ip}/work/workdone.php")
    req = Net::HTTP::Post::Multipart.new url.path,
      "file" => UploadIO.new(File.new(zipfile_name), "application/zip", "results.zip"),
      "har" => "false",
      "flattenZippedHar" => "0",
      "id" => "#{id}", "done" => "1",
      "location" => "#{location}"
      response = Net::HTTP.start(url.host, url.port) do |http|
        http.request(req)
      end
    pp resp
  end

  #We check if the HAR is present. If so, we load it.
  def process
    logMsg = Logger.new('log.txt')
    logMsg.level = Logger::WARN
    logError = Logger.new('logerror.txt')
    logError.level = Logger::ERROR

    file = File.read(@pathHar)
    har_file = JSON.parse(file)
    checks = OptimizationChecks.new

    # We sort entries by start time
    sortedEntries = Hash.new
    har_file['log']['entries'].each_with_index do |entry, key|
      start = entry['startedDateTime']
      sortedEntries["#{start} - #{key}"] = entry
    end

    sortedEntries.sort

    numPageRecords =
      if har_file['log'].has_key?('pages')
        c = 0
        har_file['log']['pages'].each do |foo|
          c = c + 1
        end
        c
      else
        0
      end

    if (numPageRecords == 0)
      # TODO Create a Page Record in the Har
    end

    pageData = Hash.new

    har_file['log']['pages'].each_with_index do |page, key|
      pageref = page['id']
      curPageData = Hash.new

      curPageData['url'] = page['title']

      startFull = page['startedDateTime']
      startFullDatePart = ""
      startFullTimePart = ""
      getDateAndTime(startFull, startFullDatePart, startFullTimePart)

      #TODO see if there is a onRender argument in POST request.
      #If so, replace UNKNOWN_TIME with this onRender
      curPageData["onRender"] = getHashWithDefault('onRender', page['pageTimings'],
                                                  getHashWithDefault('_onRender', page['pageTimings'],
                                                                    "UNKNOWN_TIME"))
    curPageData['docComplete'] = getHashWithDefault('onContentLoad', page['pageTimings'], "UNKNOWN_TIME")
    curPageData['fullyLoaded'] = getHashWithDefault('onLoad', page['pageTimings'], "UNKNOWN_TIME")
    if (curPageData['docComplete'] <= 0)
        curPageData['docComplete'] = curPageData['fullyLoaded']
    end

    #use global $urlUnderTest ?
    #

    urlMatch = /^https?:\/\/([^\/?]+)(((?:\/|\\?).*$)|$)/.match(curPageData['url'])
    if (!urlMatch.nil?)
      curPageData['host'] = urlMatch[1]
    else
      #errorLogHar()
      logError.error "Host is not in right format"
    end

    pageMatch = /page_(\d+)_([01])/.match(pageref)

    if (page.has_key?('_runNumber'))
        curPageData['run'] = page['_runNumber']
        curPageData['cached'] = page['_cachedWarmed']
    # elsif param HTTP
    elsif pageMatch
      curPageData['run'] = pageMatch[1]
      curPageData['cached'] = pageMatch[2]
    else
      # HAR error : Could not get runs or cache
      # nor from parameters

      #default values
      curPageData['run'] = 1
      curPageData['cached'] = 0
    end

    curPageData['title'] = if (curPageData['cached']) then "Cached-" else "Cleared Cache-" end
    curPageData['title'] += "Run_" + curPageData['run'].to_s + "^" + curPageData['url']

    curPageData['runFilePrefix'] = @path + "/" + curPageData['run'].to_s + "_"

    if curPageData['cached'] != 0
      curPageData['runFilePrefix'] += "Cached_"
    end

    curPageData['runFileName'] = curPageData['runFilePrefix'] + "IEWTR.txt"
    curPageData['reportFileName'] = curPageData['runFilePrefix']+ "report.txt"

    curPageData["TTFB"] = curPageData["docComplete"]

    curPageData["bytesOut"] = 0
    curPageData["bytesIn"] = 0
    curPageData["nDnsLookups"] = 0
    curPageData["nConnect"] = 0
    curPageData["nRequest"] = 0
    curPageData["nReqs200"] = 0
    curPageData["nReqs302"] = 0
    curPageData["nReqs304"] = 0
    curPageData["nReqs404"] = 0
    curPageData["nReqsOther"] = 0
    curPageData["bytesOutDoc"] = 0

    curPageData["bytesInDoc"] = 0
    curPageData["nDnsLookupsDoc"] = 0
    curPageData["nConnectDoc"] = 0
    curPageData["nRequestDoc"] = 0
    curPageData["nReqs200Doc"] = 0
    curPageData["nReqs302Doc"] = 0
    curPageData["nReqs304Doc"] = 0
    curPageData["nReqs404Doc"] = 0
    curPageData["nReqsOtherDoc"] = 0
    curPageData["reqNum"] = 0

    curPageData["calcStarTime"] = 0

    pageData[pageref] = curPageData
    curPageData = nil
    end

    b = true

    firstLoop = true

    sortedEntries.each { |key, entry|
      pageref = entry['pageref']
      startedDateTime = entry['startedDateTime']
      entryTime = entry['time']
      reqEnt = entry['request']
      respEnt = entry['response']
      cacheEnt = entry['cache']
      timingsEnt = entry['timings']

      if (reqEnt['method'] == 'HEAD')
        next
      end

      reqIpAddr = getHashWithDefault('serverIPAddress', entry, nil)

      curPageData = pageData[pageref]

      reqHttpVer = reqEnt['httpVersion']
      respHttpVer = respEnt['httpVersion']

      reqDate = ""
      reqTime = ""

      begin
        getDateAndTime(startedDateTime, reqDate, reqTime)
      rescue
        #logError problem with Date format
        logError.error "Problem with Date format"
      end

      reqEventName = curPageData['title']
      reqAction = reqEnt['method']

      urlMatch = /^https?:\/\/([^\/?]+)(((?:\/|\\?).*$)|$)/.match(reqEnt['url'])

      #skip non-http URL
      if urlMatch.nil?
        logMsg.debug "Skipping non http URL"
        next
      end

      reqUrl = urlMatch[2]
      reqHost = urlMatch[1]
      reqRespCode = respEnt['status']

      if (reqRespCode == "0")
        logMsg.debug "Skipping resp 0 resource"
        next
      end

      reqRespCodeText = respEnt['statusText']
      reqLoadTime = 0 + entryTime

      if (curPageData['calcStarTime'] == 0)
        curPageData['calcStarTime'] = startedDateTime
        curPageData['startFull'] = startedDateTime
      end

      reqStartTime = getDeltaMillisecondsFromDates(curPageData['startFull'], startedDateTime)
      if (reqStartTime < 0.0)
        logError.error "Negative start offset (#{reqStartTime}) for request\n
                        curPageData['startFull'] = #{reqStartTime}\n
                        startedDateTime = #{startedDateTime}"
      end

      requestTimings = convertHarTimes(timingsEnt, reqStartTime)
      reqDnsTime = requestTimings['dns_ms']
      reqSslTime = requestTimings['ssl_ms']
      reqConnectTime = requestTimings['connect_ms']
      reqBytesOut = (reqEnt['headersSize']).abs + (reqEnt['bodySize']).abs
      reqBytesIn = (respEnt['headersSize']).abs + (respEnt['bodySize']).abs
      reqObjectSize= (respEnt['bodySize']).abs
      reqCookieSize = 0 #TODO
      reqCookieCount = 0 #TODO
      reqExpires = 0 #TODO
      reqCacheControl = 0 #TODO
      reqContentType = respEnt['content']['mimeType']
      reqContentEncoding = 0 #TODO
      reqTransType = 3 #TODO
      reqEndTime = reqStartTime + reqLoadTime
      reqCached = 0 #TODO
      reqEventUrl = curPageData["url"]
      reqSecure = if (/^https/.match(reqEnt['url'])) then 1 else 0 end

      #TODO Use real vqlues
      reqSocketID = 3
      reqDocId = 3
      reqDescriptor = "Launch"
      reqLabId = -1
      reqDialerId = 0
      reqConnectionType = -1

      scores = ReqScores.new
      checks.getGzipScore(entry['response'], scores)
      checks.getReqKeepAliveScore(entry['request'], scores, reqUrl)
      #checks.getCDNScore(curPageData['host'])
      if (firstLoop)
        fileWTR = File.open(curPageData['runFileName'], 'w')
      else
        fileWTR = File.open(curPageData['runFileName'], 'a+')
      end
      fileWTR.write("#{reqDate}\t" +
                "#{reqTime}\t" +
                "\t" +
                "#{reqIpAddr}\t" +
                "#{reqAction}\t" +
                "#{reqHost}\t" +
                "#{reqUrl}\t" +
                "#{reqRespCode}\t" +
                "#{requestTimings['load']}\t" +
                "#{requestTimings['ttfb']}\t" +
                "#{requestTimings['start']}\t" +
                "#{reqBytesOut}\t" +
                "#{reqBytesIn}\t" +
                "#{reqObjectSize}\t" +
                "\t" + #Cookie Size
                "\t" + #Cookie Count
                "#{reqExpires}\t" +
                "#{reqCacheControl}\t" +
                "#{reqContentType}\t" +
                "#{reqContentEncoding}\t" +
                "#{reqTransType}\t" +
                "#{reqSocketID}\t" +
                "\t" + #DocId
                "#{reqEndTime}\t" +
                "\t" + # Descriptor
                "\t" + # Lab ID
                "\t" + #Dialer ID
                "\t" + #Connection Type
                "\t" + #Cached
                "\t" + #Event URL
                "\t" + # PageTest Build
                "\t" + # Measurement Type
                "\t" + # Experimental
                "\t" + # Event GUID
                "\t" + # Sequence Number
                "\t" + # Cache Score
                "\t" + # Static CDN Score
                "#{scores.gzip_score}\t" + # GZIP Score
                "\t" + # Cookie Score
                "#{scores.keep_alive_score}\t" + # Keep-Alive Score
                "\t" + # DOCTYPE Score
                "\t" + # Minify Score
                "\t" + # Combine Score
                "\t" + # Compression Score
                "\t" + # ETag Score
                "\t" + # Flagged
                "#{reqSecure}\t" +
                "-1\t" + # DNS Time
                "-1\t" + # Socket Connect Time
                "-1\t" + # SSL time
                "#{scores.gzip_total}\t" + # GZip Total Bytes
                "\t" + # GZip Savings
                "\t" + # Minify Total Bytes
                "\t" + # Minify Savings
                "\t" + # Image Compression Total Bytes
                "\t" + # Image Compression Savings
                "\t" + # Cache Time (sec)
                "\t" + # Real Start Time (ms)
                "\t" + # Full Time to Load (ms)
                "1\t" + # Optimization Checked
                "\t" + # CDN Provider
                "#{requestTimings['dns_start']}\t" + # DNS Start
                "#{requestTimings['dns_end']}\t" + # DNS end
                "#{requestTimings['connect_start']}\t" + # connect start
                "#{requestTimings['connect_end']}\t" + #connect end
                "#{requestTimings['ssl_start']}\t" + # ssl negociation start
                "#{requestTimings['ssl_end']}\t" + # ssl negociation end
                "\t \t \t" + #Initiator
                "\t" +# Server Count
                "\t" +# Server RTT
                "\t" +# Local Port
                "\t" +# JPEG scan count
                "\r\n")
      fileWTR.close

      reqNum = curPageData['reqNum'] + 1
      curPageData['reqNum'] = reqNum

      #TODO Report
      if (firstLoop)
        fileReport = File.open(curPageData['reportFileName'], 'w')
        firstLoop = false
      else
        fileReport = File.open(curPageData['reportFileName'], 'a+')
      end
      fileReport.write("Request #{reqNum}:\r\n" +
                      "Action: #{reqAction}\r\n" +
                      "Url: #{reqUrl}\r\n" +
                      "Host: #{reqHost}\r\n" +
                      "Result code: #{reqRespCode}\r\n" +
                      "Transaction time: #{reqTime} milliseconds\r\n" +
                      "Time to first byte: #{requestTimings['ttfb']} milliseconds\r\n" +
                      "Request size (out): #{reqBytesOut} Bytes\r\n" +
                      "Request size (in): #{reqBytesIn} Bytes\r\n" +
                      "Request Headers:\r\n" +
                      "#{reqAction} #{reqUrl} #{reqHttpVer}\r\n")

      reqEnt['headers'].each_with_index do |header, key|
        fileReport.write("#{header['name']}; #{header['value']}\r\n")
      end

      fileReport.write("Response Headers:\r\n" +
                      "#{respHttpVer} #{reqRespCode} #{reqRespCodeText}\r\n")

      respEnt['headers'].each_with_index do |header, key|
        fileReport.write("#{header['name']}; #{header['value']}\r\n")
      end

      fileReport.write("\r\n")

      curPageData['bytesOut'] += reqBytesOut
      curPageData['bytesIn'] += reqBytesIn
      curPageData['nDnsLookups'] += (reqDnsTime > 0) ? reqDnsTime : 0
      curPageData['nConnect'] += (reqConnectTime > 0) ? reqDnsTime : 0
      curPageData['nRequest'] += 1

      if (/^200$/.match(reqRespCode.to_s))
        curPageData['nReqs200'] += 1
      elsif (/^302$/.match(reqRespCode.to_s))
        curPageData['nReqs302'] += 1
      elsif (/^304$/.match(reqRespCode.to_s))
        curPageData['nReqs304'] += 1
      elsif (/^404$/.match(reqRespCode.to_s))
        curPageData['nReqs404'] += 1
      else
        curPageData['nReqsOther'] += 1
      end

      if (curPageData['docComplete'] > reqStartTime)
        curPageData['bytesOutDoc'] += reqBytesOut
        curPageData['bytesInDoc'] += reqBytesIn
        curPageData['nDnsLookupsDoc'] += (reqDnsTime > 0) ? reqDnsTime : 0
        curPageData['nConnectDoc'] += (reqConnectTime > 0) ? reqDnsTime :0
        if (/^200$/.match(reqRespCode.to_s))
          curPageData['nReqs200Doc'] += 1
        elsif (/^302$/.match(reqRespCode.to_s))
          curPageData['nReqs302Doc'] += 1
        elsif (/^304$/.match(reqRespCode.to_s))
          curPageData['nReqs304Doc'] += 1
        elsif (/^404$/.match(reqRespCode.to_s))
          curPageData['nReqs404Doc'] += 1
        else
          curPageData['nReqsOtherDoc'] += 1
        end
      end

      fileReport.close

      curPageData['TTFB'] = [curPageData['TTFB'], requestTimings['receive_start']].min

      pageData[pageref] = curPageData
    }

    har_file['log']['pages'].each_with_index do |page, key|
      pageref = page['id']
      curPageData = pageData[pageref]

      curPageData['resourceFileName'] = curPageData['runFilePrefix'] + "IEWPG.txt"
      if (key == 0)
        fileWPG = File.open(curPageData['resourceFileName'], 'w')
      else
        fileWPG = File.open(curPageData['resourceFileName'], 'a+')
      end

      fileWPG.write(
            "#{curPageData['startDate']}\t" +
            "#{curPageData['startTime']}\t" +
            "#{curPageData['title']}\t" +
            "#{curPageData['url']}\t" +
            "#{curPageData['fullyLoaded']}\t" +
            "#{curPageData['TTFB']}\t" +
            "\t" + #"unused\t" +
            "#{curPageData['bytesOut']}\t" +
            "#{curPageData['bytesIn']}\t" +
            "#{curPageData['nDnsLookups']}\t" +
            "#{curPageData['nConnect']}\t" +
            "#{curPageData['nRequest']}\t" +
            "#{curPageData['nReqs200']}\t" +
            "#{curPageData['nReqs302']}\t" +
            "#{curPageData['nReqs304']}\t" +
            "#{curPageData['nReqs404']}\t" +
            "#{curPageData['nReqsOther']}\t" +
            "0\t" + # TODO: Find out how to get the error code
            "#{curPageData['onRender']}\t" +
            "\t" + #"Segments Transmitted\t" +
            "\t" + #"Segments Retransmitted\t" +
            "\t" + #"Packet Loss (out)\t" +
            "#{curPageData['fullyLoaded']}\t" + #Activity Time, apparently the same as fully loaded
            "\t" + #"Descriptor\t" +
            "\t" + #"Lab ID\t" +
            "\t" + #"Dialer ID\t" +
            "\t" + #"Connection Type\t" +
            "#{curPageData['cached']}\t" +
            "#{curPageData['url']}\t" +
            "\t" + #"Pagetest Build\t" +
            "\t" + #"Measurement Type\t" +
            "\t" + #"Experimental\t" +
            "#{curPageData['docComplete']}\t" +
            "\t" + #"Event GUID\t" +
            "\t" + #"Time to DOM Element (ms)\t" +
            "1\t" + #"Includes Object Data\t" +
            "\t" + #"Cache Score\t" + TODO
            "\t" + #"Static CDN Score\t" + TODO
            "-1\t" + #"One CDN Score\t" +
            "#{checks.gzip_score}\t" + #"GZIP Score\t" +
            "-1\t" + #"Cookie Score\t" +
            "#{checks.keep_alive_score}\t" + #"Keep-Alive Score\t" + TODO
            "-1\t" + #"DOCTYPE Score\t" +
            "-1\t" + #"Minify Score\t" +
            "\t" + #"Combine Score\t" + TODO
            "#{curPageData['bytesOutDoc']}\t" +
            "#{curPageData['bytesInDoc']}\t" +
            "#{curPageData['nDnsLookupsDoc']}\t" +
            "#{curPageData['nConnectDoc']}\t" +
            "#{curPageData['nRequestDoc']}\t" +
            "#{curPageData['nReqs200Doc']}\t" +
            "#{curPageData['nReqs302Doc']}\t" +
            "#{curPageData['nReqs304Doc']}\t" +
            "#{curPageData['nReqs404Doc']}\t" +
            "#{curPageData['nReqsOtherDoc']}\t" +
            "\t" + #"Compression Score\t" +
            "#{curPageData['host']}\t" +
            "\t" + #"IP Address\t" +
            "\t" + #"ETag Score\t" +
            "\t" + #"Flagged Requests\t" +
            "\t" + #"Flagged Connections\t" +
            "\t" + #"Max Simultaneous Flagged Connections\t" +
            "\t" + #"Time to Base Page Complete (ms)\t" +
            "\t" + #"Base Page Result\t" +
            "#{checks.gzip_total}\t" + #"Gzip Total Bytes\t" +
            "\t" + #"Gzip Savings\t" +
            "\t" + #"Minify Total Bytes\t" +
            "\t" + #"Minify Savings\t" +
            "\t" + #"Image Total Bytes\t" +
            "\t" + #"Image Savings\t" +
            "\t" + #"Base Page Redirects\t" +
            "1\r\n" #"Optimization Checked\r\n"
      )
      fileWPG.close
    end
  end


end

def numeric?(str)
  Float(str) != nil rescue false
end

def positiveNumberKeyOrDefault(harRec, eventName, default)
  if !(harRec.has_key?(eventName))
    return default
  end

  value = harRec[eventName]
  if (!numeric?(value))
    return default
  end

  if (value < 0)
    return default
  end

  return value
end

def convertHarTimesToStartEndDuration(harRec, entryTime)
  harEventNames = ['blocked', 'dns', 'connect', 'send', 'wait', 'receive', 'ssl']
  eventTimes = Hash.new
  harEventNames.each do |eventName|
    duration = positiveNumberKeyOrDefault(harRec, eventName, 0)

    eventTimes[eventName] = { "ms" => duration}
  end

  lastEventEndTime = entryTime

  harEventNames.each do |eventName|
    if (eventName == 'ssl')
      next
    end
    eventTimes[eventName]['start'] = lastEventEndTime
    lastEventEndTime += eventTimes[eventName]['ms']
    eventTimes[eventName]['end'] = lastEventEndTime
  end

  eventTimes['ssl']['end'] = eventTimes['connect']['end']
  eventTimes['ssl']['start'] = eventTimes['ssl']['end'] - eventTimes['ssl']['ms']

  if (eventTimes['ssl']['start'] < eventTimes['connect']['start'])
    #Alter the ssl timig to conform to the spec
    eventTimes['ssl']['start'] = eventTimes['connect']['start']
    eventTimes['ssl']['ms'] = eventTimes['connect']['ms']
  end
  return eventTimes
end

def harTimingEventOccured(harRec, eventName)
  if (!harRec.has_key?(eventName))
    return false
  end

  eventValue = harRec[eventName]

  if (!numeric?(eventValue))
    return false
  end

  if (eventValue < 0)
    return false
  end

  return true
end

def convertHarTimes(harRec, entryTime)
  harTimes = convertHarTimesToStartEndDuration(harRec, entryTime)

  wptTimes = Hash.new

  wptTimes['start'] = harTimes['send']['start']
  wptTimes['ttfb'] = harTimes['wait']['end'] - harTimes['send']['start']
  wptTimes['load'] = harTimes['receive']['end'] - harTimes['send']['start']

  if (harTimingEventOccured(harRec, 'dns'))
    wptTimes['dns_start'] = harTimes['dns']['start']
    wptTimes['dns_end'] = harTimes['dns']['end']
  else
    wptTimes['dns_start'] = 0
    wptTimes['dns_end'] = 0
  end

  wptTimes['dns_ms'] = wptTimes['dns_end'] - wptTimes['dns_start']

  if (harTimingEventOccured(harRec, 'connect'))
    wptTimes['connect_start'] = harTimes['connect']['start']
    wptTimes['connect_end'] = harTimes['ssl']['start']
  else
    wptTimes['connect_start'] = 0
    wptTimes['connect_end'] = 0
  end

  wptTimes['connect_ms'] = wptTimes['connect_end'] - wptTimes['connect_start']

  if (harTimingEventOccured(harRec, 'ssl'))
    wptTimes['ssl_start'] = harTimes['ssl']['start']
    wptTimes['ssl_end'] = harTimes['ssl']['end']
  else
    wptTimes['ssl_start'] = 0
    wptTimes['ssl_end'] = 0
  end

  wptTimes['ssl_ms'] = wptTimes['ssl_end'] - wptTimes['ssl_start']

  wptTimes['receive_start'] = harTimes['receive']['start']

  return wptTimes
end

class Time
  def to_ms
    (self.to_f * 1000.0).to_i
  end
end

def getDeltaMillisecondsFromDates(newDate, oldDate)
  nDate = DateTime.iso8601(newDate).strftime('%Q').to_i
  oDate = DateTime.iso8601(oldDate).strftime('%Q').to_i
  ret = (oDate - nDate)
  return ret.to_i
end

def getHashWithDefault(key, hash, default)
  if hash.has_key?(key)
    return hash[key]
  else
    return default
  end
end

def getDateAndTime(datetime, date, time)
      date.replace datetime[5..6] + "/" + datetime[8..9] + "/" + datetime[0..3]
      time.replace datetime[11..18]
end
