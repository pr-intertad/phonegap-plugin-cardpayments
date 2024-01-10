/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVSquareCardPayments.h"
#import "NSURL+SCAdditions.h"
#import "NSDictionary+SCAdditions.h"

#import <Cordova/CDVAvailability.h>

// urls
NSString *const CDVSquarePaymentUrl = @"square-commerce-v1://payment/create";
NSString *const CDVSquareCallbackUrl = @"auto-shop://square-complete";

// request fields
NSString *const CDVSquarePaymentRequestUrlDataKey = @"data";
NSString *const CDVSquarePaymentRequestClientIDKey = @"clientId";
NSString *const CDVSquarePaymentRequestUserInfoStringKey = @"userInfo";
NSString *const CDVSquarePaymentRequestAmountKey = @"amount";
NSString *const CDVSquarePaymentRequestCurrencyKey = @"currency";

// response fields
NSString *const CDVSquarePaymentResponsePaymentIdKey = @"paymentId";
NSString *const CDVSquarePaymentResponseOfflinePaymentIdKey = @"offlinePaymentId";
NSString *const CDVSquarePaymentResponseStatusKey = @"status";
NSString *const CDVSquarePaymentResponseUserInfoStringKey = @"userInfo";

NSString *const CDVSquareCheckInstallResponseInstalledKey = @"installed";

// error fields
NSString *const CDVSquarePaymentErrorCodeKey = @"code";
NSString *const CDVSquarePaymentErrorDomainKey = @"domain";
NSString *const CDVSquarePaymentErrorDomain = @"com.intertad.phonegap.plugins.cardpayments.square";

@implementation CDVSquareCardPayments

- (void)checkInstalled:(CDVInvokedUrlCommand*)command
{
    UIApplication *application = [UIApplication sharedApplication];

    NSURL *squareUrl = [NSURL URLWithString:CDVSquarePaymentUrl];

    bool installed = [application canOpenURL:squareUrl];

    NSDictionary *dict = [NSDictionary dictionaryWithObject:@(installed)
      forKey:CDVSquareCheckInstallResponseInstalledKey];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                  messageAsDictionary:dict];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)createPayment:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error = nil;

    NSDictionary* params = [command.arguments objectAtIndex:0];

    NSString *clientId = [params objectForKey: CDVSquarePaymentRequestClientIDKey];
    NSString *userInfo = [params objectForKey: CDVSquarePaymentRequestUserInfoStringKey];
    NSNumber *amount = [params objectForKey: CDVSquarePaymentRequestAmountKey];
    NSString *currency = [params objectForKey: CDVSquarePaymentRequestCurrencyKey];

    [self doSquarePaymentForClientId:clientId
                            userInfo:userInfo
                            currency:currency
                              amount:amount
                               error:&error];

    if (error != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[error userInfo]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)doSquarePaymentForClientId:(NSString *)clientId
                          userInfo:(NSString *)userInfo
                          currency:(NSString *)currency
                            amount:(NSNumber *)amount
                             error:(NSError *__autoreleasing *)error {

    NSMutableDictionary *amountMoney = [NSMutableDictionary dictionary];
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    [amountMoney setObject:amount forKey:@"amount"];
    [amountMoney setObject:currency forKey:@"currency_code"];

    [parameters setObject:amountMoney forKey:@"amount_money"];
    [parameters setObject:CDVSquareCallbackUrl forKey:@"callback_url"];
    [parameters setObject:clientId forKey:@"client_id"];
    [parameters setObject:userInfo forKey:@"notes"];

    NSString *version = @"1.2";
    [parameters setObject:version forKey:@"version"];

    NSArray *tender_types = @[@"CREDIT_CARD", @"CASH", @"OTHER", @"SQUARE_GIFT_CARD", @"CARD_ON_FILE"];
    [options setValue:tender_types forKey:@"supported_tender_types"];
    [parameters setObject:options forKey:@"options"];

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&jsonError];

    if (jsonError) {
        NSLog(@"Error creating JSON data: %@", jsonError);
        *error = [NSError errorWithDomain:CDVSquarePaymentErrorDomain
                                     code:1
                                 userInfo:@{ @"message": @"Error creating JSON data" }];
        return;
    }

    NSString *jsonParameters = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSString *squareUrlString = [NSString stringWithFormat:@"%@?data=%@", CDVSquarePaymentUrl, [jsonParameters SC_URLEncodeUsingEncoding:NSUTF8StringEncoding]];

    NSURL *squareUrl = [NSURL URLWithString:squareUrlString];

    UIApplication *application = [UIApplication sharedApplication];
    if ([application canOpenURL:squareUrl]){
        [application openURL:squareUrl];
    } else {
        *error = [NSError errorWithDomain: CDVSquarePaymentErrorDomain
                                     code: 2
                                 userInfo: @{ @"message": @"Square app is not installed" }];
    }
}

- (void)handleCallback:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSURL *url = [NSURL URLWithString:[command.arguments objectAtIndex:0]];
    NSDictionary *urlParameters = [url SC_parameters];
    NSString *dataString = [urlParameters SC_stringForKey: CDVSquarePaymentRequestUrlDataKey];
    NSDictionary *dict = [NSMutableDictionary dictionary];

    if (dataString != nil) {
        NSData *jsonData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *jsonError = nil;
        NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];

        if (jsonError) {
            NSLog(@"Error parsing JSON: %@", jsonError);
            pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR messageAsString:@"Error parsing JSON"];
        } else {
            NSString *status = [data SC_stringForKey:@"status"];
            [dict setValue:status forKey:CDVSquarePaymentResponseStatusKey];
            [dict setValue:[data SC_stringForKey:@"state"] forKey:CDVSquarePaymentResponseUserInfoStringKey];

            if ([status isEqualToString:@"ok"]) {
                [dict setValue:[data SC_stringForKey:@"payment_id"] forKey:CDVSquarePaymentResponsePaymentIdKey];
                [dict setValue:[data SC_stringForKey:@"offline_payment_id"] forKey:CDVSquarePaymentResponseOfflinePaymentIdKey];

                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            } else {
                [dict setValue:[data SC_stringForKey:@"error_code"] forKey:CDVSquarePaymentErrorCodeKey];
                [dict setValue:CDVSquarePaymentErrorDomain forKey:CDVSquarePaymentErrorDomainKey];

                pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR messageAsDictionary: dict];
            }
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR messageAsString:@"No data provided"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
