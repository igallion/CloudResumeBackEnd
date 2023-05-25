import json
import boto3
import botocore

client = boto3.client('dynamodb')
dynamoTable = 'CloudResumeVisitorsTerraform'


def increment_count():
    # TODO implement
    print('Incrementing visitor count for resume site now')
    client = boto3.client('dynamodb')
    response = client.update_item(
        TableName=dynamoTable,
        Key={
            'stat': {
                'S': 'view-count',
            },
        },
        UpdateExpression="SET Quantity = Quantity + :incr",
        ExpressionAttributeValues={
            ":incr": {"N": "1"}
        },
        ReturnValues="UPDATED_NEW"
    )

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,GET'
        },
        'body': json.dumps(response)
    }


def initialize_Table():
    print("Initializing table")
    init_Result = client.put_item(
        TableName=dynamoTable,
        Item={
            'stat': {'S': 'view-count'},
            'Quantity': {'N': '0'}
        },
        ConditionExpression='attribute_not_exists(stat) AND attribute_not_exists(Quantity)',
        ReturnValues="ALL_OLD"
    )
    """
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,GET'
        },
        'body': json.dumps(init_Result)
    }
    """


def lambda_handler(event, context):
    try:
        initialize_Table()
        count = increment_count()
        return count
    except botocore.exceptions.ClientError as e:
        # Ignore the ConditionalCheckFailedException, bubble up
        # other exceptions.
        if e.response['Error']['Code'] != 'ConditionalCheckFailedException':
            raise
        else:
            print("Table already initialized, incrementing count")
            count = increment_count()
            return count
