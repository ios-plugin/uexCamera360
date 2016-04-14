/**
 *
 *	@file   	: EUExCamera360.mm  in EUExCamera360
 *
 *	@author 	: CeriNo 
 * 
 *	@date   	: Created on 16/1/5.
 *
 *	@copyright 	: 2015 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "EUExCamera360.h"
#import "EUtility.h"
#import "JSON.h"
#import "uexCamera360EditViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>





@interface EUExCamera360()<UINavigationControllerDelegate, UIImagePickerControllerDelegate,pg_edit_sdk_controller_delegate>
@property (nonatomic,strong)NSString *identifier;
@property (nonatomic,assign)BOOL isPresenting;
@property (nonatomic,strong)NSString *saveFolderPath;
@property (nonatomic,strong)NSString *fullSavePath;
@property (nonatomic,assign)BOOL usePNG;

@property (nonatomic,assign)BOOL isStatusBarHidden;

@end


typedef NS_ENUM(NSInteger,uexCamera360CallbackResult) {
    uexCamera360CallbackSuccess = 0,
    uexCamera360CallbackErrorSourceImagePathError = -1,
    uexCamera360CallbackErrorImageAlbumUnavailable = -2,
    uexCamera360CallbackErrorFetchAlbumImageFailed = -3,
    uexCamera360CallbackErrorUserCancelled = -4,
    uexCamera360CallbackErrorNoChangeAdded = -5,
    uexCamera360CallbackErrorSavePathError = -6
};


@implementation EUExCamera360

#pragma mark - Life Cycle

- (instancetype)initWithBrwView:(EBrowserView *)eInBrwView{
    self=[super initWithBrwView:eInBrwView];
    if(self){

    }
    return self;
}

- (void)clean{
    self.isPresenting=NO;
    self.identifier=nil;
    self.saveFolderPath=nil;
    self.fullSavePath=nil;
    self.usePNG=NO;


}

- (void)dealloc{
    [self clean];
}





#pragma mark - API

- (void)setAPIKey:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return;
    }
    NSString *APIKey = info[@"APIKey"];
    if(!APIKey || ![APIKey isKindOfClass:[NSString class]] || [APIKey length] == 0){
        return;
    }
    [self initializeWithKey:APIKey];
}


- (void)edit:(NSMutableArray *)inArguments{
    if([inArguments count] < 1 || self.isPresenting){
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return;
    }
    NSString *identifier = info[@"id"]?[NSString stringWithFormat:@"%@",info[@"id"]]:nil;
    if(!identifier){
        return;
    }
    NSString *savePath= info[@"imgSavePath"] && [info[@"imgSavePath"] isKindOfClass:[NSString class]]?info[@"imgSavePath"]:nil;
    if(!savePath){
        return;
    }
    self.identifier=identifier;
    self.saveFolderPath=[self absPath:savePath];
    NSString *imgSrcPath=info[@"imgSrcPath"] && [info[@"imgSrcPath"] isKindOfClass:[NSString class]]?info[@"imgSrcPath"]:nil;
    if (!imgSrcPath || [imgSrcPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        //从相册选取图片
        [self launchImagePickerController];
        return;
    }
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:[self absPath:imgSrcPath]];
    if(!sourceImage){
        [self cbEditWithResult:uexCamera360CallbackErrorSourceImagePathError];
        return;
    }
    
    //检查是否是png
    NSString *ext = imgSrcPath.lastPathComponent.pathExtension.lowercaseString;
    if ([ext isEqual:@"png"]) {
        self.usePNG=YES;
    }
    [self launchCamera360ViewControllerWithImage:sourceImage];
    
    
}

#pragma mark - Private

- (void)cbEditWithResult:(uexCamera360CallbackResult)result{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@((NSInteger)result) forKey:@"errorCode"];
    [dict setValue:self.identifier forKey:@"id"];
    if (self.fullSavePath) {
        [dict setValue:self.fullSavePath forKey:@"saveFilePath"];
    }
    [self callbackJSONWithFunction:@"cbEdit" object:dict];
    [self clean];
}

- (void)launchImagePickerController{
    self.isPresenting=YES;
    UIImagePickerController *picker=[[UIImagePickerController alloc] init];
    [picker setDelegate:self];
    [picker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    picker.mediaTypes = @[@"public.image"];
    [self presentModelViewController:picker];
}

- (void)launchCamera360ViewControllerWithImage:(UIImage *)sourceImage{
    [self initializeWithKey:nil];
    self.isPresenting=YES;
    pg_edit_sdk_controller_object *obj=[[pg_edit_sdk_controller_object alloc] init];
    obj.pCSA_fullImage=sourceImage;
    uexCamera360EditViewController *vc=[[uexCamera360EditViewController alloc]initWithEditObject:obj withDelegate:self];
    self.isStatusBarHidden=[UIApplication sharedApplication].isStatusBarHidden;
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    [self presentModelViewController:vc];
    
}

- (void)presentModelViewController:(__kindof UIViewController *)vc{
    dispatch_async(dispatch_get_main_queue(), ^{
        [EUtility brwView:self.meBrwView presentModalViewController:vc animated:YES];
    });
}

- (void)initializeWithKey:(NSString *)APIKey{
    
    if(!APIKey || APIKey.length == 0){
        APIKey = [[NSBundle mainBundle]infoDictionary][@"uexCamera360APIKey"];
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
         [pg_edit_sdk_controller sStart:APIKey];
    });
}

- (void)checkIfPNGFromAssetURL:(NSURL *)assetURL{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation *repr = [asset defaultRepresentation];
        if ([[repr UTI] isEqualToString:@"public.png"]) {
            self.usePNG=YES;
        }
    } failureBlock:^(NSError *error) {
        
    }];
}

- (NSString *)uniqueSavePath{
    NSDate *date=[NSDate dateWithTimeIntervalSinceNow:0];
    return [self.saveFolderPath stringByAppendingPathComponent:@(ceil(date.timeIntervalSince1970*1000)).stringValue];
}

- (BOOL)saveImage:(UIImage *)resultImage{
    NSData *imageData;
    NSString *suffix;
    if(self.usePNG){
        imageData = UIImagePNGRepresentation(resultImage);
        suffix=@".png";
    }else{
        imageData = UIImageJPEGRepresentation(resultImage, 0.75);
        suffix=@".jpg";
    }
    NSString *savePath = [self.uniqueSavePath stringByAppendingString:suffix];
    self.fullSavePath=savePath;
    BOOL isImageSaved = [imageData writeToFile:savePath atomically:YES];
    return isImageSaved;
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    UIImage *sourceImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    if(!sourceImage){
        [self cbEditWithResult:uexCamera360CallbackErrorFetchAlbumImageFailed];
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self checkIfPNGFromAssetURL:[info valueForKey:UIImagePickerControllerReferenceURL]];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [picker dismissViewControllerAnimated:YES completion:^{
            self.isPresenting=NO;
            [self launchCamera360ViewControllerWithImage:sourceImage];
        }];
    });
    


}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    dispatch_async(dispatch_get_main_queue(), ^{
        [picker dismissViewControllerAnimated:YES completion:^{
            self.isPresenting=NO;
            [self cbEditWithResult:uexCamera360CallbackErrorUserCancelled];
        }];
    });
}

#pragma mark - pg_edit_sdk_controller_delegate
/**
 *  完成后调用，点击保存，object 是 pg_edit_sdk_controller_object 对象
 *  Invoke after completion, click save, object's target is pg_edit_sdk_controller_object
 */
- (void)dgPhotoEditingViewControllerDidFinish:(UIViewController *)pController
                                       object:(pg_edit_sdk_controller_object *)object{

   dispatch_async(dispatch_get_main_queue(), ^{
       [pController dismissViewControllerAnimated:YES completion:^{
           dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) , ^{
               BOOL isImageSaved=[self saveImage:[UIImage imageWithData:object.pOutEffectOriData]];
               if(!isImageSaved){
                   [self cbEditWithResult:uexCamera360CallbackErrorSavePathError];
                   return;
               }
               [self cbEditWithResult:uexCamera360CallbackSuccess];
           });
       }];
   });
}

/**
 *  完成后调用，点击取消
 *  Invoke after completion, click cancel
 */

- (void)dgPhotoEditingViewControllerDidCancel:(UIViewController *)pController withClickSaveButton:(BOOL)isClickSaveBtn{
    dispatch_async(dispatch_get_main_queue(), ^{
        [pController dismissViewControllerAnimated:YES completion:^{
            [[UIApplication sharedApplication] setStatusBarHidden:self.isStatusBarHidden withAnimation:UIStatusBarAnimationFade];
            if(!isClickSaveBtn){
                [self cbEditWithResult:uexCamera360CallbackErrorUserCancelled];
                return;
            }
            [self cbEditWithResult:uexCamera360CallbackErrorNoChangeAdded];
        }];
    });
}



///**
// *  当需要长时间等待时会调用此接口，如果没有实现此协议，那么将用默认系统Loading代替，开始Loading回调
// *  This interface is invoked when waiting for long periods of time, if you did not implement this protocol, it will be replaced by system default Loading, start Loading callback
// */
//- (void)dgPhotoEditingViewControllerShowLoadingView:(UIView*)view{
//    
//}
//
///**
// *  当需要长时间等待结束时会调用此接口，如果没有实现此协议，那么将用默认系统Loading代替，结束Loading回调
// *  This interface is invoked when waiting for long periods of time to end, if you did not implement this protocol, it will be replaced by system default Loading, end Loading callback
// */
//- (void)dgPhotoEditingViewControllerHideLoadingView:(UIView*)view{
//    
//}


#pragma mark - JSON Callback

- (void)callbackJSONWithFunction:(NSString *)functionName object:(id)object{
    [EUtility uexPlugin:@"uexCamera360"
         callbackByName:functionName
             withObject:object
                andType:uexPluginCallbackWithJsonString
               inTarget:self.meBrwView];
}



@end
