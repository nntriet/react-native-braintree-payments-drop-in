#import "RNBraintreeDropIn.h"

@implementation RNBraintreeDropIn

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_REMAP_METHOD(show,
                 showWithOptions:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }

    BTDropInRequest *request = [[BTDropInRequest alloc] init];
    if(options[@"disablePayPal"] == nil || [options[@"disablePayPal"] boolValue]) {
        request.paypalDisabled = YES;
    } else {
        request.paypalDisabled = NO;
    }

    NSDictionary* threeDSecureOptions = options[@"threeDSecure"];
    if (threeDSecureOptions) {
        NSNumber* threeDSecureAmount = threeDSecureOptions[@"amount"];
        if (!threeDSecureAmount) {
            reject(@"NO_3DS_AMOUNT", @"You must provide an amount for 3D Secure", nil);
            return;
        }
        
        BTThreeDSecureRequest *threeDSecureRequest = [[BTThreeDSecureRequest alloc] init];
        threeDSecureRequest.amount = [threeDSecureAmount stringValue];
        threeDSecureRequest.versionRequested = BTThreeDSecureVersion2;
//        threeDSecureRequest.email = @"test@email.com";

//        BTThreeDSecurePostalAddress *address = [BTThreeDSecurePostalAddress new];
//        address.givenName = @"Jill"; // ASCII-printable characters required, else will throw a validation error
//        address.surname = @"Doe"; // ASCII-printable characters required, else will throw a validation error
//        address.phoneNumber = @"5551234567";
//        address.streetAddress = @"555 Smith St";
//        address.extendedAddress = @"#2";
//        address.locality = @"Chicago";
//        address.region = @"IL";
//        address.postalCode = @"12345";
//        address.countryCodeAlpha2 = @"US";
//        threeDSecureRequest.billingAddress = address;

//         Optional additional information.
//         For best results, provide as many of these elements as possible.
//        BTThreeDSecureAdditionalInformation *additionalInformation = [BTThreeDSecureAdditionalInformation new];
//        additionalInformation.shippingAddress = address;
//        threeDSecureRequest.additionalInformation = additionalInformation;

        request.threeDSecureVerification = YES;
        request.threeDSecureRequest = threeDSecureRequest;
    }

    BTDropInController *dropIn = [[BTDropInController alloc] initWithAuthorization:clientToken request:request handler:^(BTDropInController * _Nonnull controller, BTDropInResult * _Nullable result, NSError * _Nullable error) {
            [self.reactRoot dismissViewControllerAnimated:YES completion:nil];

            if (error != nil) {
                reject(error.localizedDescription, error.localizedDescription, error);
            } else if (result.cancelled) {
                reject(@"USER_CANCELLATION", @"The user cancelled", nil);
            } else {
                if (threeDSecureOptions && [result.paymentMethod isKindOfClass:[BTCardNonce class]]) {
                    BTCardNonce *cardNonce = (BTCardNonce *)result.paymentMethod;
                    if (!cardNonce.threeDSecureInfo.liabilityShiftPossible && cardNonce.threeDSecureInfo.wasVerified) {
                        reject(@"3DSECURE_NOT_ABLE_TO_SHIFT_LIABILITY", @"3D Secure liability cannot be shifted", nil);
                    } else if (!cardNonce.threeDSecureInfo.liabilityShifted && cardNonce.threeDSecureInfo.wasVerified) {
                        reject(@"3DSECURE_LIABILITY_NOT_SHIFTED", @"3D Secure liability was not shifted", nil);
                    } else {
                        [[self class] resolvePayment :result resolver:resolve];
                    }
                } else {
                    [[self class] resolvePayment :result resolver:resolve];
                }
            }
        }];

    if (dropIn != nil) {
        [self.reactRoot presentViewController:dropIn animated:YES completion:nil];
    } else {
        reject(@"INVALID_CLIENT_TOKEN", @"The client token seems invalid", nil);
    }
}

+ (void)resolvePayment:(BTDropInResult* _Nullable)result resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
    NSMutableDictionary* jsResult = [NSMutableDictionary new];
    [jsResult setObject:result.paymentMethod.nonce forKey:@"nonce"];
    [jsResult setObject:result.paymentMethod.type forKey:@"type"];
    [jsResult setObject:result.paymentDescription forKey:@"description"];
    [jsResult setObject:[NSNumber numberWithBool:result.paymentMethod.isDefault] forKey:@"isDefault"];
    resolve(jsResult);
}

- (UIViewController*)reactRoot {
    UIViewController *root  = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *maybeModal = root.presentedViewController;

    UIViewController *modalRoot = root;

    if (maybeModal != nil) {
        modalRoot = maybeModal;
    }

    return modalRoot;
}

@end
