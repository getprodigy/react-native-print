
//  Created by Christopher Dro on 9/4/15.

#import "RNPrint.h"
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>

@implementation RNPrint

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(print:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    NSArray *pathItems;
    NSString *filePath;
    NSString *htmlString;
    NSURL *printerURL;
    UIPrinter *pickedPrinter;
    BOOL isLandscape = false;

    if (options[@"pathItems"]){
        pathItems = [RCTConvert NSArray:options[@"pathItems"]];
    }

    if (options[@"filePath"]){
        filePath = [RCTConvert NSString:options[@"filePath"]];
    }

    if (options[@"html"]){
        htmlString = [RCTConvert NSString:options[@"html"]];
    }

    if (options[@"printerURL"]){
        printerURL = [NSURL URLWithString:[RCTConvert NSString:options[@"printerURL"]]];
        pickedPrinter = [UIPrinter printerWithURL:printerURL];
    }

    if(options[@"isLandscape"]) {
        isLandscape = [[RCTConvert NSNumber:options[@"isLandscape"]] boolValue];
    }
    if ((filePath && htmlString && pathItems) || (filePath == nil && htmlString == nil && pathItems == nil)) {
        reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@"Must provide either `html` or `filePath` or `urlItems`."));
    }

    NSData *printData;
    BOOL isValidURL = NO;
    NSURL *candidateURL = [NSURL URLWithString: filePath];
    if (candidateURL && candidateURL.scheme && candidateURL.host)
        isValidURL = YES;

    NSMutableArray *printingItems;

    if (isValidURL) {
        // TODO: This needs updated to use NSURLSession dataTaskWithURL:completionHandler:
        printData = [NSData dataWithContentsOfURL:candidateURL];
    } else if (pathItems) {
        printingItems = [[NSMutableArray alloc] init];
        for(int i = 0; i < [pathItems count]; i++) {
            NSData *data = [NSData dataWithContentsOfFile: pathItems[i]];
            if (data) {
                [printingItems addObject:data];
            }
        }
    } else {
        printData = [NSData dataWithContentsOfFile: filePath];
    }

    UIPrintInteractionController *printInteractionController = [UIPrintInteractionController sharedPrintController];
    printInteractionController.delegate = self;

    // Create printing info
    UIPrintInfo *printInfo = [UIPrintInfo printInfo];

    printInfo.outputType = UIPrintInfoOutputGeneral;
    printInfo.duplex = UIPrintInfoDuplexLongEdge;
    printInfo.orientation = isLandscape? UIPrintInfoOrientationLandscape: UIPrintInfoOrientationPortrait;

    printInteractionController.printInfo = printInfo;
    printInteractionController.showsPageRange = YES;
    printInteractionController.showsNumberOfCopies = NO;

    if (htmlString) {
        UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:htmlString];
        printInteractionController.printFormatter = formatter;
    } else {
        printInteractionController.printingItems = printingItems;
    }

    // Completion handler
    void (^completionHandler)(UIPrintInteractionController *, BOOL, NSError *) =
    ^(UIPrintInteractionController *printController, BOOL completed, NSError *error) {
        if (!completed && error) {
            NSLog(@"Printing could not complete because of error: %@", error);
            reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(error.description));
        } else {
            resolve(nil);
        }
    };

    if (pickedPrinter) {
        [printInteractionController printToPrinter:pickedPrinter completionHandler:completionHandler];
    } else if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) { // iPad
        UIView *view = [[UIApplication sharedApplication] keyWindow].rootViewController.view;
        [printInteractionController presentFromRect:view.frame inView:view animated:YES completionHandler:completionHandler];
    } else { // iPhone
        [printInteractionController presentAnimated:YES completionHandler:completionHandler];
    }
}


RCT_EXPORT_METHOD(selectPrinter:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    UIPrinterPickerController *printPicker = [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter: _pickedPrinter];

    printPicker.delegate = self;

    void (^completionHandler)(UIPrinterPickerController *, BOOL, NSError *) =
    ^(UIPrinterPickerController *printerPicker, BOOL userDidSelect, NSError *error) {
        if (!userDidSelect && error) {
            NSLog(@"Printing could not complete because of error: %@", error);
            reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(error.description));
        } else {
            [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:printerPicker.selectedPrinter];
            if (userDidSelect) {
                _pickedPrinter = printerPicker.selectedPrinter;
                NSDictionary *printerDetails = @{
                                                 @"name" : _pickedPrinter.displayName,
                                                 @"url" : _pickedPrinter.URL.absoluteString,
                                                 };
                resolve(printerDetails);
            }
        }
    };

    if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) { // iPad
        UIView *view = [[UIApplication sharedApplication] keyWindow].rootViewController.view;
        float x = [options[@"x"] floatValue];
        float y = [options[@"y"] floatValue];
        [printPicker presentFromRect:CGRectMake(x, y, 0, 0) inView:view animated:YES completionHandler:completionHandler];
    } else { // iPhone
        [printPicker presentAnimated:YES completionHandler:completionHandler];
    }
}

#pragma mark - UIPrintInteractionControllerDelegate

-(UIViewController*)printInteractionControllerParentViewController:(UIPrintInteractionController*)printInteractionController  {
    UIViewController *result = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    while (result.presentedViewController) {
        result = result.presentedViewController;
    }
    return result;
}

-(void)printInteractionControllerWillDismissPrinterOptions:(UIPrintInteractionController*)printInteractionController {}

-(void)printInteractionControllerDidDismissPrinterOptions:(UIPrintInteractionController*)printInteractionController {}

-(void)printInteractionControllerWillPresentPrinterOptions:(UIPrintInteractionController*)printInteractionController {}

-(void)printInteractionControllerDidPresentPrinterOptions:(UIPrintInteractionController*)printInteractionController {}

-(void)printInteractionControllerWillStartJob:(UIPrintInteractionController*)printInteractionController {}

-(void)printInteractionControllerDidFinishJob:(UIPrintInteractionController*)printInteractionController {}

@end
