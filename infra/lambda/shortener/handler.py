import json
import boto3
import os
import re
import time
import random
import string
from botocore.exceptions import ClientError


TABLE_NAME = os.environ.get("TABLE_NAME", "")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


allowed = ("http://", "https://")
 
code_length = 6
code_chars = string.ascii_uppercase + string.digits

def make_response(status_code, body_dict): 
    return {
        "statusCode": status_code, #like 200 or 400
        "headers": { 
            "Content-Type": "application/json", #declare that it is json
            'Access-Control-Allow-Origin': '*', #siumple CORS
            # 'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
        },
        "body": json.dumps(body_dict) #Api gateway expects a string body
    }

def is_valid_url(url): #function to check if the url is valid, not foolproof, just some precausions
    if not isinstance(url, str)or len(url) > 3000:  #if the url is not a string and is very long
        return False  #return false
    
    if not url.startswith(allowed): #if the url does not start with http 
        return False #return false
    
    pattern = r"^https?://[A-Za-z0-9.-]+(?::\d+)?(?:/\S*)?$"
    
    return re.match(pattern, url) is not None #if it matches the regex pattern, return true and continue

def generate_unique_code(): #generate a random 6 length code that will serve as the shortened url
    code = ''.join(random.choices(code_chars, k=code_length))
    return code





def read_long_url(event): #read the long url on events
    #event 1- direct lambda call/invoke with {"long_url": "..."}
    #event 2- api gateway http api call where event["body"] is a json string
    
    #if call invoked directly with dict that has long url
    if isinstance(event, dict) and "long_url" in event:
        return str(event["long_url"])
    
    #if call from an api gateway and it is a json string
    if isinstance(event, dict) and isinstance(event.get("body"), str): 
        try:
            body = json.loads(event["body"]) #turn the json string into a dict
            return str(body["long_url", ""]) # return the url or "" if missing
        except Exception:
            # print(e)
            return "" #if bad json, treat as empty
        
    return "" #if all else fails, return empty string
    
    
    




#create a shortener stub that returns a JSON payload so we can deploy and test
def lambda_handler(event, context): 
    long_url = read_long_url(event) #get the long url from the event
        
    if not is_valid_url(long_url): #if the url is not valid
        return make_response(400, {"error": "Invalid URL. Use http:// or https://"}) #return a 400 error

    #store the long url and code in dynamodb
    for _ in range(5): #try a few times in case it messes up
        code = generate_unique_code() #generate a code
        try:
            table.put_item(
                Item={
                    "short_code": code, #the partition key
                    "long_url": long_url, #where to redirect
                    "created_at": int(time.time()) #time created for good measure
                },
                ConditionExpression="attribute_not_exists(short_code)" #collisiton safe
            )
            return make_response(200, {"short_code": code}) #it is sucessful, return the short code as json
        
        except ClientError as e:
            if e.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException": #if condition failed, maybe code already exists, so continue instead of returning
                continue
            return make_response(500, {"error": "DynamoDB Internal Server Error"}) #return 500 since error in our side and
    
    return make_response(500, {"error": "Could not generate a unique code."}) #if still did not generate after 5 tries, then mayeb the link is wrong 
    
    
    
    
