## Compliance API - Ruby client

### Gnip Compliance API

To ensure that the Twitter user's voice is continually respected, Gnip's customers are obligated to maintain compliant data stores... meaning that requests to delete or otherwise alter data are acted on and propagated through the customer's data analysis framework. To enable customers to comply, Gnip provides aa API endpoint from which all compliance data related to a customer's account can be regularly requested. A full description of the API can be found at the [Gnip support site](http://support.gnip.com/apis/compliance_api/).

### So, what does this Compliance API client do?
Helps automate real-time requests to the Compliance API.





This example project consists of several resources:
* compliance_api.rb: the 'main' client program that is excuted with various options (see below).
* pt_restful.rb: a common-code HTTP helper class currently based on the stsndard Ruby net/https gem.
* pt_logging: a common-code Logger class currently based on the Ruby 'logging' gem.
* example_config.yaml: Compliance Client configuration file.
 
### Client run-time options



* Search start and end time can be specified in several ways: standard PowerTrack timestamps (YYYYMMDDHHMM), 
  ISO 8061/Twitter timestamps (2013-11-15T17:16:42.000Z), as "YYYY-MM-DD HH:MM", and also with simple notation indicating the number of minutes (30m), hours (12h) and days (14d).

Configuration and rule details can be specified by passing in files or specifying on the command-line, or a combination of both.  Here are some quick example:
  * Using configuration and rules files, requesting 30 days: $ruby search_api.rb -c "./myConfig.yaml" -r "./myRules.json"
  * Using configuration and rules in files, requesting last 7 days: $ruby search_api.rb -c "./myConfig.yaml" -r "./myRules.json" -s 7d
  * Specifying everything on the command-line: $ruby search_api.rb -u me@there.com -p password -a http://search.gnip.com/accounts/jim/search/prod.json -r "profile_region:colorado snow" -s 7d 






This Compliance API client was designed anticipating several use-cases:
* Real-time execution
* One-time back-fill execution:




**Command-line options**

Three optional command-line parameters can be provided:

```
Usage: compliance_api [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and download settings.
                                         Config files include username, password, account name and stream label/name.
    -s, --start_time START           UTC timestamp for beginning of Search period.
                                           Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m. If set to 'file', a local 'start_time.dat' file is used to track Compliance API calls.
    -e, --end_time END               UTC timestamp for ending of Search period.
                                        Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -h, --help                       Display this screen.

```













While the linked documentation provides a complete description of a single query, this package:
* Automates the query generation.
* Automates the periodic submission of queries.
* Manages common connection errors.
* Standardizes the data output.

The recommended practice is to query the API for 10-minute time intervals, with a delay of at least 5 minutes between the end of the time interval and the current time. Missed data can be obtained with a series of custom queries of no more than 10 minutes in length. 





Run 'options'

* Explicit start and end dates via command-line or in config file.
* Explicit start date via command-line or in config file. end-date defaults to now-5mins
* Explicit start date set to 'file' via command-line or in config file.
      if no file exists, go back hours specified in 'initial_go_back'



