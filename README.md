# Compliance API - Ruby client

## Introduction

To ensure that the Twitter user's voice is continually respected, Gnip's customers are obligated to maintain compliant data stores... meaning that requests to delete or otherwise alter data are acted on and propagated through the customer's data analysis framework. To enable customers to comply, Gnip provides aa API endpoint from which all compliance data related to a customer's account can be regularly requested. A full description of the API can be found at the [Gnip support site](http://support.gnip.com/apis/compliance_api/).

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



