import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as fs from 'fs';
import * as path from 'path';
import * as codecommit from 'aws-cdk-lib/aws-codecommit';
import * as sqs from 'aws-cdk-lib/aws-sqs';

export class KKamijoTestStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = ec2.Vpc.fromLookup(this, 'Vpc', {
      vpcId: 'vpc-0fa225abf143438e0',
    });

    const role = new iam.Role(this, 'Ec2Role', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
      ],
    });

    const repo = new codecommit.Repository(this, 'SetupRepo', {
      repositoryName: 'github-runner-setup',
      code: codecommit.Code.fromDirectory(path.join(__dirname, 'runner-scripts')),
    });

    // CodeCommitへのアクセス権
    repo.grantRead(role);

    // Secrets Managerへのアクセス権
    role.addToPolicy(new iam.PolicyStatement({
      actions: ['secretsmanager:GetSecretValue'],
      resources: ['arn:aws:secretsmanager:ap-northeast-1:971416076373:secret:github-pat-*'],
    }));

    const securityGroup = new ec2.SecurityGroup(this, 'SecurityGroup', {
      vpc,
      description: 'Security group for GitHub Actions Runner',
      allowAllOutbound: true,
    });
    const userDataScript = fs.readFileSync(path.join(__dirname, 'user-data.sh'), 'utf8');
    const userData = ec2.UserData.forLinux();
    userData.addCommands(userDataScript);

    const instance = new ec2.Instance(this, 'GithubRunner', {
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PUBLIC },
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T4G, ec2.InstanceSize.MICRO),
      machineImage: ec2.MachineImage.fromSsmParameter(
      '/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id'
    ),
      role,
      securityGroup,
      userData,
      requireImdsv2: true,
    });
  }
}
