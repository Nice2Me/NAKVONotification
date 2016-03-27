//
//  ViewController.m
//  NAKVODemo
//
//  Created by zuopengl on 3/27/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "ViewController.h"
#import "MAKVONotificationCenter.h"
#import "NAKVONotificationCenter.h"


@interface Person : NSObject

@property (nonatomic, assign) int age;
@property (nonatomic, copy) NSString *name;
@end

@implementation Person
@end


@interface ViewController ()
@property (nonatomic, strong) Person *people;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.people = [[Person alloc] init];
    [self.people addObserver:self keyPath:@"age" selector:@selector(changeForKeyPath:object:notification:userInfo:) userInfo:nil options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld];
    [self.people addObserver:self keyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld block:^(MAKVONotification *notification) {
        
    }];
    [self.people na_addObserver:self keyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld block:^(NAKVONotification *notification) {
        
    }];
    
    [self.people setValue:@(10) forKey:@"age"];
    [self.people setValue:@"liuzp" forKey:@"name"];
  
}

- (void)changeForKeyPath:(NSString *)keyPath object:(id)object notification:(MAKVONotification *)notification userInfo:(id)userInfo {
    
}


- (IBAction)didTapRemoveObserver:(id)sender {
    NSString *key = self.textField.text;
    if ([key length] > 0) {
        [self.people removeObserver:self keyPath:key];
        [self.people na_removeObserver:self keyPath:key];
    }
}

- (IBAction)didTapReleaseObject:(id)sender {
    [self.people removeAllObservers];
    [self.people na_removeAllObservers];
    self.people = nil;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
