## AWS CDK Deployment

Copied and adapted from upstream TiTiler deploy example: [v2.4.0](https://github.com/developmentseed/titiler/tree/dac9fa0b213df1df925575abc73656fe0a950f50/deployment/aws).

### (Re)deployment steps (adapted from: https://developmentseed.org/titiler/deployment/aws/lambda/#deploy)

> Add `--profile <role>` to cdk commands below to get the appropriate AWS creds.

Initial setup:

```
# Download titiler repo
git clone https://github.com/ohmg-dev/deployment
cd titiler_lambda_cdk

# Install NodeJS dependencies
npm install -g aws-cdk@2.159.1

# Deploys the CDK toolkit stack into an AWS environment
uv run cdk bootstrap
```

Deploy current repo:

```
# Synthesizes and prints the CloudFormation template for this stack
uv run cdk synth titiler-lambda-{dev|production}

# Deploys the stack(s) using default app names
uv run cdk deploy titiler-lambda-{dev|production}
```

The final arg here will default to `titiler-lambda-production`. Really it can be anything, but must be consistent through all these steps, as the deploy step expects the stack name that has been synthed.

Destroy the entire stack (seems to reliably remove all AWS resources):

```
uv run cdk destroy titiler-lambda-{dev|production}
```