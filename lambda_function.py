import json
import boto3


def lambda_handler(event, context):
    # TODO implement
    print('Incrementing visitor count for resume site now')
    client = boto3.client('dynamodb')
    response = client.update_item(
        TableName='CloudResumeVisitorsTerraform',
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
