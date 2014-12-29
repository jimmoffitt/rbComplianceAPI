#!/usr/bin/env ruby
__author__ = "Jim Moffitt"

#TODOs:
#     [] Have mechanism to persist endpoint, for subsequent run....? last_run.dat file? Rewrite yaml file?
#     [X] Logging?
#     [] Filling all oComp attributes?
#     [] encrypted password
#     [X] Start compliance calls
#     [X] Handle output

require 'optparse'
require 'base64'
require 'time'
require 'json'
require_relative './pt_restful'

require 'logging'

class ComplianceAPIClient

  attr_accessor :http, #need a HTTP object to make requests of.
                :urlCompliance, #End-point.

                :account_name, :user_name,
                :password, :password_encoded, #System authentication.
                :publisher, #Twitter only.
                :product, :stream_type, :label, #These are currently not in Compliance URI.

                :run_mode,
                :start_time, :end_time,

                :use_start_file, :start_time_file,
                :initial_go_back, #in hours. If start_time set to 'file', and file doesn't exist, go back this far on initial run.
                :sleep_time, #in seconds.
                :query_length, #in seconds.

                :storage,
                :out_box,
                :compress_files,

                :logger,
                :log_file_path


  #Can only ask for Compliance data from 5-minutes ago.
  COMPLIANCE_MIN_LATENCY = 300 #SECONDS.

  def initialize

    #class variables.
    @@base_url = "https://compliance.gnip.com/accounts/"

    #Initialize stuff.

    #Defaults.
    @publisher = "twitter"
    @run_mode = "one_time"
    @start_time_file = './start_time.dat'
    @initial_go_back = 24
    @sleep_time = 10
    @time_offset = 600
    @query_length = 600

    @storage = "files" #No other option implemented yet.
    @out_box = "./data"
    @compressed_files = true

    @log_file_path = './compliance_api.log'
    logger = Logging.logger(STDOUT)
    logger.level = :info


    #Set up a HTTP object.
    #TODO: OR use Search API demo objects...
    @http = PtRESTful.new

  end

  def logger=(logger)
    @logger = logger
  end

  def write_start_time
    #Take the current end_time and write it out to start_time_file.
    f = File.open(@start_time_file, 'w')
    f.write(@end_time.strftime('%F %H:%M'))
    f.close
  end

  def run
    @logger.debug "Running..."

    if @run_mode == "real-time" then

      #No times provided? Then set defaults.
      if @start_time.nil? and @end_time.nil? then
        @start_time.utc = Time.now.utc - @query_length - COMPLIANCE_MIN_LATENCY
        @end_time.utc = @start_time + @query_length
      elsif @end_time.nil?
        @start_time = Time.parse("#{@start_time}Z")
        @end_time = @start_time + @query_length
      else
        @start_time = Time.parse("#{@start_time}Z")
        @end_time = Time.parse("#{@start_time}Z")
      end

      #Hold-off if needed before initial run.
      while Time.now.utc < (@end_time + @query_length + COMPLIANCE_MIN_LATENCY)
        sleep 30
      end

      while true
        make_request(@start_time, @end_time) if Time.now.utc < (@end_time + @query_length + COMPLIANCE_MIN_LATENCY)

        while Time.now.utc < (@end_time + @query_length + COMPLIANCE_MIN_LATENCY)
          sleep @sleep_time
        end

        @start_time = @end_time
        @end_time = @start_time + @query_length

      end
    else
      make_request(@start_time, @end_time)
    end
  end

  def make_request(start_time, stop_time)

    @urlCompliance = @http.getComplianceURL(@account_name)

    parameters = {}
    parameters['fromDate'] =  get_date_string(@start_time)
    parameters['toDate'] =  get_date_string(@end_time)
    parameters['product'] = @product unless @product.nil?
    parameters['stream_type'] = @stream_type unless @stream_type.nil?
    parameters['label'] = @label unless @label.nil?

    headers = {}
    headers['Content-Type'] = 'application/json'
    headers['accept'] = 'application/json'
    #headers['Accept-Encoding'] = 'gzip'

    logger.info("Calling Compliance API with GET(#{parameters.to_s}")
    response = @http.GET(parameters, headers)

    data = response.body

    if response.code != "200" then
      logger.error("Error #{response.code} response code from Compliance API.")
    else
      if @use_start_file then
        write_start_time
      end
    end

    write_data data, @start_time, @end_time

  end

  def write_data(response, start_time, end_time)

    #Cast timestamps into Time objects.
    begin
      st = Time.parse("#{start_time}Z").utc
      et = Time.parse("#{end_time}Z").utc
    rescue => e
      logger.error("Error creating Time objects: #{e.message} | #{e.to_s}")
    end

    #Create output folders.
    begin
      file_path = "#{@out_box}/#{st.year}/#{'%02d' % st.month}/#{'%02d' % st.day}/#{'%02d' % st.hour}"
      FileUtils.mkdir_p(file_path)
    rescue => e
      logger.error("Error creating output folder: #{e.message} | #{e.to_s}")
    end

    #Create output file.
    begin
      file_name = "compliance-#{st.year}-#{'%02d' % st.month}-#{'%02d' % st.day}-#{'%02d' % st.hour}.json"
      f = File.open("#{file_path}/#{file_name}",'w+')

      logger.debug("Writing output file #{file_name}")

      f.write(response)
      f.close
    rescue => e
      logger.error("Error creating output folder: #{e.message} | #{e.to_s}")
    end
  end


  #Load in the configuration file details, setting many object attributes.
  def get_app_config(config_file)

    #logger.debug 'Loading configuration file.'

    config = YAML.load_file(config_file)

    #Config details.

    #Parsing account details if they are provided in file.
    if !config["account"].nil? then
      if !config["account"]["account_name"].nil? then
        @account_name = config["account"]["account_name"]
      end

      if !config["account"]["user_name"].nil? then
        @user_name = config["account"]["user_name"]
      end

      if !config["account"]["password"].nil? or !config["account"]["password_encoded"].nil? then
        @password_encoded = config["account"]["password_encoded"]

        if @password_encoded.nil? then #User is passing in plain-text password...
          @password = config["account"]["password"]
          @password_encoded = Base64.encode64(@password)
        end
      end
    end

    @http.user_name = @user_name
    @http.password_encoded = @password_encoded

    #Product configuration, all are optional.
    if !config['product'].nil? then
      @product = config['product']['product']
      @stream_type = config['product']['stream_type']
      @label = config['product']['label']
    end

    #App settings.
    @run_mode = config['app']['run_mode']
    @start_time = config['app']['start_time']
    @initial_go_back = config['app']['initial_go_back']
    @end_time = config['app']['end_time']
    @sleep_time = config['app']['sleep_time_in_seconds']
    @time_offset = config['app']['time_offset_in_seconds']
    @query_length = config['app']['query_length_in_seconds']
    @storage = config['app']['storage']

    begin
      @out_box = checkDirectory(config["compliance"]["out_box"])
    rescue
      @out_box = "./data"
    end

    begin
      @compress_files = config["compliance"]["compress_files"]
    rescue
      @compress_files = false
    end


    @log_file_path = config['app']['log_file_path']

    if @storage == "database" then #Get database connection details.
      db_host = config["database"]["host"]
      db_port = config["database"]["port"]
      db_schema = config["database"]["schema"]
      db_user_name = config["database"]["user_name"]
      db_password = config["database"]["password"]

      @datastore = PtDatabase.new(db_host, db_port, db_schema, db_user_name, db_password)
      @datastore.connect
    end
  end

  #TODO: implement.
  def check_config

    config_ok = true

    if @user_name.nil? then
        p 'Error: no user_name.'
        return false
    end

    return config_ok
  end

  def get_date_string(time)
    return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
  end

  #Takes a variety of string inputs and returns a standard PowerTrack YYYYMMDDHHMM timestamp string.
  def set_date_string(input)

    now = Time.new
    date = Time.new

    #Handle minute notation.
    if input.downcase[-1] == "m" then
      date = now - (60 * input[0..-2].to_f)
      return get_date_string(date)
    end

    #Handle hour notation.
    if input.downcase[-1] == "h" then
      date = now - (60 * 60 * input[0..-2].to_f)
      return get_date_string(date)
    end

    #Handle day notation.
    if input.downcase[-1] == "d" then
      date = now - (24 * 60 * 60 * input[0..-2].to_f)
      return get_date_string(date)
    end

    #Handle PowerTrack format, YYYYMMDDHHMM
    if input.length == 12 and numeric?(input) then
      return input
    end

    #Handle "YYYY-MM-DD 00:00"
    if input.length == 16 then
      return input.gsub!(/\W+/, '')
    end

    #Handle ISO 8601 timestamps, as in Twitter payload "2013-11-15T17:16:42.000Z"
    if input.length > 16 then
      date = Time.parse(input)
      return get_date_string(date)
    end


    logger.info("ERROR: could not parse 'start_time'. ")
    return 'Error, unrecognized timestamp.'

  end

end

#-------------------------------------------------------------------------------------------------------------------
#Options:
#  Pass in nothing, look locally for configuration file.
#  Pass in configuration file.
#  Pass in selected parameters on command-line:
#       outbox
#       start time
#       end time

#Example command-lines:
# $ruby ./compliance_api.rb
# $ruby ./compliance_api.rb -c "./ComplianceConfig.yaml"
# $ruby ./compliance_api.rb -c "./ComplianceConfig.yaml" -s "2013-10-18 06:00" -e "2013-10-20 06:00"
# $ruby ./compliance_api.rb -s "2013-10-18 06:00" -e "2013-10-20 06:00"

#Compliance API object init has base-line defaults.
#Next looks for local config.yaml, and overwrites with anything provided there.
#Finally, takes passed in command-line parameters, overwriting


#-------------------------------------------------------------------------------------------------------------------

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.



  logger = Logging.logger(STDOUT)
  logger.level = :info
  logger.info("Program started")

  #Create Compliance API object.
  logger.debug("Creating Compliance API object.")
  oComp = ComplianceAPIClient.new()
  oComp.start_time_file = './start_time.dat'

  #logger = Logger.new File.new(oComp.log_file_path)
  oComp.logger = logger

  logger.debug("Passing #{ARGV.length/2} arguments on command-line")

  if ARGV.length > 0 then

    OptionParser.new do |o| #Process any parameters passed-in via command-line.

      #Passing in a config file.... Or you can set a bunch of parameters.
      o.on('-c CONFIG', '--config', 'Configuration file (including path) that provides account and download settings.
                                         Config files include username, password, account name and stream label/name.') { |config| $config = config}

      #The following parameters need to be provided by configuration file. Command-line not yet supported.
      #Basic Authentication.
      #o.on('-u USERNAME','--user', 'User name for Basic Authentication.  Same credentials used for console.gnip.com.') {|username| $username = username}
      #o.on('-p PASSWORD','--password', 'Password for Basic Authentication.  Same credentials used for console.gnip.com.') {|password| $password = password}

      #Search URL, based on account name.
      #o.on('-a ADDRESS', '--address', 'Either Search API URL, or the account name which is used to derive URL.') {|address| $address = address}
      #o.on('-n NAME', '--name', 'Label/name used for Stream API. Required if account name is supplied on command-line,
      #                               which together are used to derive URL.') {|name| $name = name}

      #Period of search.  Defaults to end = Now(), start = Now() - 30.days.
      o.on('-s START', '--start_time', "UTC timestamp for beginning of Search period.
                                           Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.") { |start_time| $start_time = start_time}
      o.on('-e END', '--end_time', "UTC timestamp for ending of Search period.
                                        Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.") { |end_time| $end_time = end_time}

      o.on('-o OUTBOX', '--outbox', 'Optional. Triggers the generation of files and where to write them.') {|outbox| $outbox = outbox}

      #Help screen.
      o.on( '-h', '--help', 'Display this screen.' ) do
        puts o
        exit
      end

      o.parse!

    end
  end

  #Load configuration file.
  config_file_path = "./config.yaml" #Default location and name.
  if !$config.nil? then
    config_file_path = $config #Or overwritten from command-line.
  end
  oComp.get_app_config(config_file_path)

  #We need to end up with PowerTrack timestamps in YYYYMMDDHHmm format.
  #If numeric and length = 12 then we are all set.
  #If ISO format and length 16 then apply o.gsub!(/\W+/, '')
  #If ends in m, h, or d, then do some time.add math

  read_start_time = false

  #Handle start date.
  #First see if it was passed in
  if !$start_time.nil? then

    if $start_time == 'file' then
      oComp.use_start_file = true
      if !File.exist?(oComp.start_time_file)
        oComp.start_time = oComp.set_date_string("#{oComp.initial_go_back}h")
      else
        read_start_time = true
      end
    else
      oComp.start_time = oComp.set_date_string($start_time)
    end
  end

  #Handle end date.
  #First see if it was passed in
  if !$end_time.nil? then
    oComp.end_time = oComp.set_date_string($end_time)
  end


  if oComp.start_time == 'file' then
    oComp.use_start_file = true
    if !File.exist?(oComp.start_time_file)
      oComp.start_time = oComp.set_date_string("#{oComp.initial_go_back}h")
    else
      read_start_time = true
    end
  end

  if read_start_time then
    start_time_dat = File.read(oComp.start_time_file)
    oComp.start_time = oComp.set_date_string(start_time_dat)
  end

  if oComp.check_config then
    oComp.run
  else
    p 'Problem with configuration. Please check and retry.'
    logger.error 'Problem with configuration. Not running...'
  end
end



=begin

 Random notes around HTTP gems...


 # Sample code for using rest-client HTTP gem:
 #data = {query: 'gnip', publisher: 'twitter', maxResults: 100}
    #auth = 'Basic ' + Base64.encode64( "#{user_name}:#{password}" ).chomp
    #url = "https://search.gnip.com:443/accounts/#{account_name}/search/#{stream_label}/counts.json"
    #headers = {:Authorization => auth, :content_type => :'application/json', :accept => :json }
    #response = RestClient.get(url, {headers, :params => {:query => rule}})

    #response = RestClient::Request.new(method: :post, url: url, user: user_name, payload: data,
    #                                   password: password, timeout: 30, open_timeout: 30,
    #                                   headers: headers).execute
    #response = RestClient::Request.new(method: :post, url: url, payload: Yajl::Encoder.encode(data),
    #                                   timeout: 30, open_timeout: 30,
    #                                   headers: headers).execute
=end