%% 'undefined' port mean that standard port for the chosen scheme is used
-record(aws_config, {
          as_host="autoscaling.amazonaws.com"::string(),
          ec2_host="ec2.amazonaws.com"::string(),
          iam_host="iam.amazonaws.com"::string(),
          sts_host="sts.amazonaws.com"::string(),
          s3_scheme="https://"::string(),
          s3_host="s3.amazonaws.com"::string(),
          s3_port::non_neg_integer()|undefined,
          sdb_host="sdb.amazonaws.com"::string(),
          elb_host="elasticloadbalancing.amazonaws.com"::string(),
          ses_host="email.us-east-1.amazonaws.com"::string(),
          sqs_host="queue.amazonaws.com"::string(),
          sns_scheme="http://"::string(),
          sns_host="sns.amazonaws.com"::string(),
          mturk_host="mechanicalturk.amazonaws.com"::string(),
          mon_host="monitoring.amazonaws.com"::string(),
          mon_port::non_neg_integer()|undefined,
          mon_protocol=undefined::string()|undefined,
          ddb_scheme="https://"::string(),
          ddb_host="dynamodb.us-east-1.amazonaws.com"::string(),
          ddb_port::non_neg_integer()|undefined,
          kinesis_scheme="https://"::string(),
          kinesis_host="kinesis.us-east-1.amazonaws.com"::string(),
          kinesis_port::non_neg_integer()|undefined,
          cloudtrail_scheme="https://"::string(),
          cloudtrail_host="cloudtrail.amazonaws.com"::string(),
          cloudtrail_port::non_neg_integer()|undefined,
          cloudtrail_api_prefix="CloudTrail_20131101."::string(),
          access_key_id::string()|undefined|false,
          secret_access_key::string()|undefined|false,
          security_token=undefined::string()|undefined,
          % if timeout is a tuple, the first value will be used for first
          % request attempt and the second for the rest
          timeout=10000::timeout()|{timeout(),timeout()},
          cloudtrail_raw_result=false::boolean(),
          %% Default to not retry failures (for backwards compatability).
          %% Recommended to be set to default_retry to provide recommended retry behavior.
          %% See erlcloud_retry for full documentation.
          retry=fun erlcloud_retry:default_retry/1::erlcloud_retry:retry_fun(),
          retry_result=fun erlcloud_retry:default_result/1::erlcloud_retry:result_fun()
         }).
-type(aws_config() :: #aws_config{}).

-record(aws_request,
        {
          %% Provided by requesting service
          uri :: string() | binary(),
          method :: atom(),
          request_headers :: [{string(), string()}],
          request_body :: binary(),

          %% Read from response
          attempt = 0 :: integer(),
          response_type :: ok | error,
          error_type :: aws | httpc,
          httpc_error_reason :: term(),
          response_status :: pos_integer(),
          response_status_line :: string(),
          response_headers :: [{string(), string()}],
          response_body :: binary(),
          
          %% Service specific error information
          should_retry :: boolean()
        }).

