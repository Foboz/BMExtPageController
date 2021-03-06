//
//  URBNCustomPageController.m
//  PRSNTR
//
//  Created by Benjamin Müller on 11.04.13.
//  Copyright (c) 2013 urbn. All rights reserved.
//

#import "BMExtendablePageController.h"
#import "NSLayoutConstraint+PlacementHelper.h"
#import "NSView+BMImageRepresentation.h"

@implementation BMExtendablePageController{
    NSMutableArray* _pages;
    NSMutableDictionary* _freeViewController;
    
    Boolean _temporaryDisabled;
}

#pragma mark - INIT
-(id)init{
    if ((self = [super init])) {
        [self setup];
    }

    return self;
}

-(id)initWithDelegate:(id<BMExtendablePageControllerDelegate>)aDelegate{
    if ((self = [self init])) {
        self.delegate = aDelegate;
    }
    
    return self;
}

-(id)initWithDelegate:(id<BMExtendablePageControllerDelegate>)aDelegate arrangedObjects:(NSArray *)arrangedObjects completed:(void (^)())completion{
    
    if ((self = [self initWithDelegate:aDelegate])) {
        [self setArrangedObjects:arrangedObjects completed:completion];
    }
    
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    if ((self = [super initWithCoder:aDecoder])) {
        [self setup];
    }
    return self;
}

-(id)initWithFrame:(RECT)frameRect{
    if ((self = [super initWithFrame:frameRect])) {
        [self setup];
    }
    
    return self;
}

-(void)setup{
    _temporaryDisabled = false;
    _selectedIndex = 0;
    _arrangedObjects = nil;
    _loggingEnabled = FALSE;
    _pages = [[NSMutableArray alloc] init];
    _freeViewController = [[NSMutableDictionary alloc] init];
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
}

#pragma mark - PUBLIC
-(void)setArrangedObjects:(NSArray *)arrangedObjects{

    [self setArrangedObjects:arrangedObjects completed:nil];
}

-(void)setArrangedObjects:(NSArray *)arrangedObjects completed:(void (^)())completion{
    _arrangedObjects = [arrangedObjects copy];
    
    // remove any views currently displayed
    for (VIEW_CONTROLLER* vCtrl in _pages) {
        if (![vCtrl isKindOfClass:[NSNull class]] && vCtrl.view) {
            [vCtrl.view removeFromSuperview];
        }
    }
    
    [_pages removeAllObjects];
    [_freeViewController removeAllObjects];
    
    for (int i=0; i<_arrangedObjects.count; i++) {
        [_pages addObject:[NSNull null]];
    }
    
    // quit now, if there are no page items
    if (_pages.count <= 0) {
        if(completion) completion();
        
        return;
    }
    
    // otherise load first pages
    _selectedIndex = 0;
    
    NSAssert(_delegate, @"Make sure to assign a delegate for the page controller");
    
    [self updatePageCache:^{
        
        assert(![[_pages objectAtIndex:_selectedIndex] isKindOfClass:[NSNull class]]);
        
        _selectedViewController = [_pages objectAtIndex:_selectedIndex];
        
        [self presentSelectedViewController];
        
        if(completion) completion();
    }];
}

-(void)setSelectedIndex:(NSInteger)selectedIndex withTransition:(id<BMExtendablePageTransition>)transition{
    
    if(_temporaryDisabled) return;
    
    // check bounds
    if(selectedIndex >= _pages.count || selectedIndex < 0){
        if (_delegate && [_delegate respondsToSelector:@selector(pageController:invalidIndex:)]) {
            [_delegate pageController:self invalidIndex:selectedIndex];
        }
        return;
    }
    
    _temporaryDisabled = TRUE;
    
    NSAssert(_selectedIndex < _pages.count,
             @"_selectedIndex is %i, but there are only %i pages",_selectedIndex,(int)_pages.count);
    
    VIEW* currentView = [(VIEW_CONTROLLER*)[_pages objectAtIndex:_selectedIndex] view];
    
    // check if next page is preloaded otherwise load it now
    if([[_pages objectAtIndex:selectedIndex] isKindOfClass:[NSNull class]]) [self loadPageWithIndex:(int)selectedIndex];
    
    VIEW* nextView = [(VIEW_CONTROLLER*)[_pages objectAtIndex:selectedIndex] view];
    
    // inform delegate that we're going to transition views
    if(_delegate && [_delegate respondsToSelector:@selector(pageControllerWillStartTransition:)])
        [_delegate pageControllerWillStartTransition:self];
    
    if (! transition) {
        _selectedIndex = selectedIndex;
        _temporaryDisabled = FALSE;
        _selectedViewController = [_pages objectAtIndex:_selectedIndex];
        [self presentSelectedViewController];

        [self updatePageCache:nil];
        
        return;
    }
    
    [((id <BMExtendablePageTransition>) transition) transitionFromIndex:(int)_selectedIndex
                                                                   toIndex:(int)selectedIndex
                                                             andCurrenView:currentView
                                                                toNextView:nextView
                                                           onContainerView:self
                                                            withCompletion:^(){
                                                                
                                                                currentView.frame = [self parkingPosition];
                                                                
                                                                _selectedIndex = selectedIndex;
                                                                _selectedViewController = [_pages objectAtIndex:_selectedIndex];
                                                                _temporaryDisabled = FALSE;
                                                                [self updatePageCache:nil];
                                                                
                                                                if(_delegate && [_delegate respondsToSelector:@selector(pageController:didTransitionToObject:)])
                                                                    [_delegate pageController:self didTransitionToObject:[_arrangedObjects objectAtIndex:_selectedIndex]];
                                                            }];

}

-(void)nextPageWithTransitionStyle:(id<BMExtendablePageTransition>)transition{
    
    [self setSelectedIndex:_selectedIndex+1 withTransition:transition];
}

-(void)prevPageWithTransitionStyle:(id<BMExtendablePageTransition>)transition{
    
    [self setSelectedIndex:_selectedIndex-1 withTransition:transition];
}

-(id<BMExtendableContinuousPageTransition>)attachContinuousTransition:(id<BMExtendableContinuousPageTransition>)transition{
    
    VIEW* currentView = [(VIEW_CONTROLLER*)[_pages objectAtIndex:_selectedIndex] view];
    
    VIEW* nextView = nil;
    if (_selectedIndex+1 < _arrangedObjects.count)
        nextView = [(VIEW_CONTROLLER*)[_pages objectAtIndex:_selectedIndex+1] view];
    
    VIEW* prevView = nil;
    if (_selectedIndex > 0)
        prevView = [(VIEW_CONTROLLER*)[_pages objectAtIndex:_selectedIndex-1] view];
    
    // inform delegate that we're going to transition views
    if(_delegate && [_delegate respondsToSelector:@selector(pageControllerWillStartTransition:)])
        [_delegate pageControllerWillStartTransition:self];
    
    [transition beginTransitionWithCurrentView:currentView
                                      nextView:nextView prevView:prevView
                               onContainerView:self
                                withCompletion:^(VIEW *nowActiveView) {
        
                                    if (nowActiveView == currentView){
                                        prevView.frame = [self parkingPosition];
                                        nextView.frame = [self parkingPosition];
                                    }else
                                        currentView.frame = [self parkingPosition];

                                    if (nowActiveView == nextView) {
                                        prevView.frame = [self parkingPosition];
                                        _selectedIndex++;
                                    }else if(nowActiveView == prevView){
                                        nextView.frame = [self parkingPosition];
                                        _selectedIndex--;
                                    }
                                     _selectedViewController = [_pages objectAtIndex:_selectedIndex];
                                    
                                    [self updatePageCache:nil];
                                    
                                    if(_delegate && [_delegate respondsToSelector:@selector(pageController:didTransitionToObject:)])
                                        [_delegate pageController:self didTransitionToObject:[_arrangedObjects objectAtIndex:_selectedIndex]];
    }];
    
    return transition;
}

#pragma mark - PROPERTIES
-(void)setSelectedIndex:(NSInteger)selectedIndex{
    [self setSelectedIndex:selectedIndex withTransition:nil];
}

#pragma mark - VIEW STUFF
-(void)presentSelectedViewController{

    VIEW* currentView = _selectedViewController.view;
        
    [NSLayoutConstraint fillSuperView:currentView];
}


#pragma mark - HELPER
-(void)updatePageCache:(void (^)())complete{
    
    // first unload exisiting pages to possibly free recyclable controllers
    // second load newly required pages
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        @synchronized(_pages)
        {
            for (int idx = 0;idx <_pages.count;idx++) {
                id obj = [_pages objectAtIndex:idx];
                // don't delete pages in active range
                if (idx >= MAX(0,_selectedIndex - PAGE_CONTROLLER_PRELOAD_RANGE) &&
                 idx <= MIN(_arrangedObjects.count - 1,
                          _selectedIndex + PAGE_CONTROLLER_PRELOAD_RANGE) )
                 continue;

                // don't care about empty pages
                if ([obj isKindOfClass:[NSNull class]])
                 continue;

                // recycle objects
                [self depositViewControllerWithIndex:idx];
                [_pages replaceObjectAtIndex:idx withObject:[NSNull null]];

                idx++;
            }
            
            // now process the currently active indices
            int startIndx = (int) MAX(0, _selectedIndex-PAGE_CONTROLLER_PRELOAD_RANGE);
            int stopIdx = (int) MIN(_arrangedObjects.count, _selectedIndex + PAGE_CONTROLLER_PRELOAD_RANGE +1);
            
            if(_loggingEnabled) NSLog(@"loading active indices at %i - %i",startIndx,stopIdx-1);
            
            for (int idx=startIndx; idx<stopIdx; idx++) {
                id obj = [_pages objectAtIndex:idx];
                
                if ([obj isKindOfClass:[NSNull class]]) {
                    [self loadPageWithIndex:idx];
                }
            }
            
            // return to main thread
            dispatch_async(dispatch_get_main_queue(), ^{

                if (complete) complete();
            });
        }
    });
}

-(void)loadPageWithIndex:(int)index{
    VIEW_CONTROLLER* pageCtrl;
    
    // check if already created
    if (![[_pages objectAtIndex:index] isKindOfClass:[NSNull class]])
        return;
    
    if(_loggingEnabled) NSLog(@"load page with idx: %i",index);

    // get a viewcontroller for index
    pageCtrl = [self requireViewControllerForIndex:index];
    [_delegate pageController:self prepareViewController:pageCtrl withObject:[_arrangedObjects objectAtIndex:index]];

    // store viewcontroller
    [_pages replaceObjectAtIndex:index withObject:pageCtrl];
    
    // add views to container
  if ([NSThread isMainThread]) {
    pageCtrl.view.frame = [self parkingPosition];
    [self addSubview:pageCtrl.view];
  } else {
    dispatch_sync(dispatch_get_main_queue(), ^{
      
      pageCtrl.view.frame = [self parkingPosition];
      [self addSubview:pageCtrl.view];
    });
  }
}


-(VIEW_CONTROLLER*)requireViewControllerForIndex:(int)index{
    // ask delegate for viewcontroller
    NSString* pageId = [_delegate pageController:self identifierForIndex:index];
    
    NSMutableArray* freeViewCtrlForPageId = [_freeViewController valueForKey:pageId];
    
    if (freeViewCtrlForPageId && freeViewCtrlForPageId.count > 0) {
        // if there is one - recycle
        id obj = [freeViewCtrlForPageId lastObject];
        [freeViewCtrlForPageId removeLastObject];
        return obj;
    }else{
        // or recreate a new
        return [_delegate pageController:self
             viewControllerForIdentifier:pageId];
    }
}

-(void)depositViewControllerWithIndex:(int)index{
    
    if(_loggingEnabled) NSLog(@"deposit page with idx: %i",index);
    
    NSString* pageId = [_delegate pageController:self identifierForIndex:index];
    
    NSMutableArray* freeViewCtrlForPageId = [_freeViewController valueForKey:pageId];
    
    // if there is not an array already - create one
    if (!freeViewCtrlForPageId){
        freeViewCtrlForPageId = [NSMutableArray array];
        [_freeViewController setObject:freeViewCtrlForPageId
                                forKey:_freeViewController];
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        VIEW_CONTROLLER* viewCtrl = [_pages objectAtIndex:index];
        [viewCtrl.view removeFromSuperview];
        [freeViewCtrlForPageId addObject:viewCtrl];
    });
}

// view controllers currently added but not in transition are "parked" somewhere to the right side of the container
-(RECT)parkingPosition{

    return CGRectOffset(self.bounds, self.bounds.size.width * PARKING_X_OFFSET_MULTIPLICATOR, 0);
}

@end
