import os
import json
import re
import time
import boto3
from botocore.exceptions import ClientError

TABLE_NAME = os.environ.get("TABLE_NAME", "")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

CODE = re.compile(r"^[A-Z0-9]{6}$") #regex to check if the code is valid

PATH_CODE = re.compile(r"/r/([A-Z0-9]{6})(?:/)?$") #in case it is something liek "/r/83A5E8" extract the code only


#api gateway expects a dict with statuscode, headers and body
def json_response(status, data): #func to return json with cors
    return { 
        "statusCode": status, #the numeric http status
        "headers": {
            "Content-Type": "application/json", #its json
            "Access-Control-Allow-Origin": "*", #allow calls from any origin 
            'X-Content-Type-Options': 'nosniff', #security header
            'X-Frame-Options': 'DENY', #security header
            'X-XSS-Protection': '1; mode=block', #security header
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains', #security header
            # "Access-Control-Allow-Credentials": True
        },
        "body": json.dumps(data), #the api gateway string body
    }
    
    
#support direct lambda invoke and api gateway http api 
def read_from_event(event): #funvction to read short code from event
    
    if isinstance(event, dict): #only handle dict events
        
        #{"code": "..."}
        if "code" in event: #if they key "code" exists 
            return str(event["code"]) #then return as string
        
        #{"short_code": "..."}
        if "short_code" in event:  #now if diff invoke "short_code"
            return str(event["short_code"])
        
        #now if http api route parameters
        path_parameters = event.get("pathParameters") or event.get("path_parameters") or {}
        if isinstance(path_parameters, dict) and "code" in path_parameters:
            return str(path_parameters["code"]) #return the path params
        
        #now last one, parse the raw string
        path = event.get("rawPath") or event.get("path") or "" #diff keys across gateways
        check = PATH_CODE.search(path) #try to match the code 
        if check:  #if matched then return the ccode
            return check.group(1)
        
    return ""


#now the main lambda handler which will look up the short code and issue an http redirect
def lambda_handler(event, context): 
    code = read_from_event(event) #get the code from the event
    
    if not code: 
        return json_response(400, {"error": "Invalid code."}) #if no code, return 400
    
    try: 
        dyTable = table.get_item(Key={"short_code": code}) #try to get the item from dynamodb
        item = dyTable.get("Item") #get the item from the response
        
    except ClientError as e: 
        return json_response(500, {"error" : f"DynamoDB internal error: {e.response['Error']['Message']}"})
    
    if not item: 
        return json_response(404, {"error": "Short code not found."}) #if no item, return 404
    
    long_url = item["long_url"]  #the dest url 
    
    try:
        table.update_item(
            Key = {"short_code": code}, #the key to update, same key
            UpdateExpression = "ADD clicks :one SET last_accessed = :ts", #the update expression
            ExpressionAttributeValues = {":one": 1,
                                         ":ts": int(time.time())} #the value to increment by
        )
    except ClientError as e:
        pass
    
    # For API Gateway HTTP API, return a 200 with redirect in body
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/html",
            "Location": long_url
        },
        "body": f'<html><head><meta http-equiv="refresh" content="0; url={long_url}"></head><body><p>Redirecting to <a href="{long_url}">{long_url}</a></p></body></html>'
    }   