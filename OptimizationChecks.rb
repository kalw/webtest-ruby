require 'socket'

class OptimizationChecks
  attr_accessor :keep_alive_score, :keep_count, :keep_total, :gzip_score, :gzip_total, :gzip_target,
                :image_compression_score, :cache_score, :combine_score,
                :static_cdn_score, :progressive_jpeg_score

  def initialize()
    @keep_count = 0
    @keep_total = 0
    @keep_alive_score = -1
    @gzip_score = -1
    @gzip_total = 0
    @gzip_target = 0
    @image_compression_score = -1
    @cache_score = -1
    @combine_score = -1
    @combine_score = -1
    @static_cdn_score = -1
    @progressive_jpeg_score = -1
  end

  def getReqKeepAliveScore(req, scores, reqUrl)

    headerKeep = false
    host = ""
    req['headers'].each do |entry|
        if (entry['name'].casecmp('host') == 0)
          host = entry['value']
        end
      end
    toto = ""
    toto += "GET #{reqUrl} #{req['httpVersion']}\r\n"
    toto2 = toto

    req['headers'].each do |entry|
      if (entry['name'] == 'Connection')
        toto += "Connection: close\r\n"
        toto2 += "Connection: keep-alive\r\n"
      else
        toto += "#{entry['name']}: #{entry['value']}\r\n"
        toto2 += "#{entry['name']}: #{entry['value']}\r\n"
      end
    end
      port = 80
      s = TCPSocket.open(host, port)
      s.puts toto2
      s.puts "\r\n"
      s.puts toto
      s.puts "\r\n"
      isAlive = 0
      testK = 0
      testC = 0
      while line = s.gets do
        if (line.scan(/HTTP\/1.1/).count > 0)
          isAlive += 1
        end
        if (line.downcase.scan(/http\/1.1 200/).count > 0)
          testK += 1
        end
      end
      s.close

    if (isAlive == 2 && testK == 2)
      scores.keep_alive_score = 100
    elsif (isAlive == 2 && testK != 2)
      scores.keep_alive_score = -1
    else
      scores.keep_alive_score = 0
    end
    if (scores.keep_alive_score != -1)
      @keep_total += scores.keep_alive_score
      @keep_count += 1
      @keep_alive_score = @keep_total / @keep_count
    end

  end

  def getCDNScore(host, resp, scores)
    listCDN = []
  end

  def getGzipScore(resp, scores)
    score = -1
    count = false

    if (resp.has_key?('status')) && (resp['status'] == 200)

       resp['headers'].each do |entry|
         if (entry['name'].casecmp('content-encoding') == 0)
           encoding = entry['value'].downcase
           score = 0
           numRequestBytes = 0

           resp['headers'].each do |entry|
             if (entry['name'].casecmp('content-length') == 0)
              numRequestBytes = entry['value'].to_i
             end
           end
           targetRequestBytes = numRequestBytes

           if ((encoding.include? 'gzip') || (encoding.include? 'deflate'))
             score = 100
           elsif (numRequestBytes < 1400)
             score = -1
           end

           if (score == 0)
             origSize = numRequestBytes
             body = resp[]
             bodyLen = body.length
           end

           if (score != -1)
             count = true
             scores.gzip_total = numRequestBytes
             @gzip_target += targetRequestBytes
             @gzip_total += numRequestBytes
           end
         end
       end
    end
    if (count && @gzip_total)
      @gzip_score = @gzip_target * 100 / @gzip_total
    end
    scores.gzip_score = score
  end
end