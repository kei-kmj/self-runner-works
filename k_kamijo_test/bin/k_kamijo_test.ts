#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { KKamijoTestStack } from '../lib/k_kamijo_test-stack';

const app = new cdk.App();
new KKamijoTestStack(app, 'KKamijoTestStack', {
    env: {
    account: '971416076373',
    region: 'ap-northeast-1',
  },
});