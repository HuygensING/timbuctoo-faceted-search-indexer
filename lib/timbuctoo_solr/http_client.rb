include Net

class HttpClient

  def initialize(base_url, authorization: nil)
    @base_url = base_url
    @authorization = authorization
  end

  def make_uri(path, query = nil)
    base_url = @base_url
    if !@base_url.end_with?("/")
      base_url += "/"
    end
    if path.start_with?("/")
      path = path[1..-1]
    end
    uri = URI(base_url + path)
    if query
      uri.query = URI.encode_www_form(query)
    end
    uri
  end

  def send_http(req, do_retry, successCodes)
    retries = 0
    max_retries = 5
    description = req.method + " at " + req.uri.to_s
    req['Authorization'] = @authorization unless @authorization.nil?
    STDERR.puts "#{description}"
    begin
      http = HTTP.new(req.uri.hostname, req.uri.port)
      http.read_timeout = 600 #seconds, so this is 10 minutes
      http.use_ssl = req.uri.scheme.eql?("https")
      response = http.request(req)
    rescue Exception => e
      STDERR.puts "#{description} failed with #{e}"
      STDERR.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
      if do_retry && retries <= max_retries
        retries += 1
        max_sleep_seconds = Float(2 ** retries)
        sleeptime = rand(0..max_sleep_seconds)
        STDERR.puts "Retrying in #{sleeptime} seconds."
        sleep sleeptime
        retry
      else
        raise "Giving up after #{retries} retries."
      end
    end
    if !successCodes.include?(response.code)
      raise "#{description} failed with status #{response.code}\n\n#{response.body}"
    end
    response
  end
end