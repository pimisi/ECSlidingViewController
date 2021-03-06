// MEDynamicTransition.m
// TransitionFun
//
// Copyright (c) 2013, Michael Enriquez (http://enriquez.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MEDynamicTransition.h"
#import "ECSlidingAnimationController.h"

@interface MEDynamicTransition ()
@property (nonatomic, strong) ECSlidingAnimationController *defaultAnimationController;
@property (nonatomic, assign) id<UIViewControllerContextTransitioning> transitionContext;
@property (nonatomic, strong) UIDynamicAnimator *animator;
@property (nonatomic, strong) UICollisionBehavior *collisionBehavior;
@property (nonatomic, strong) UIAttachmentBehavior *attachmentBehavior;
@property (nonatomic, strong) UIPushBehavior *pushBehavior;
@property (nonatomic, strong) UIDynamicBehavior *compositeBehavior;
@property (nonatomic, assign) BOOL positiveLeftToRight;
@property (nonatomic, assign) BOOL isPanningRight;
@property (nonatomic, assign) BOOL isInteractive;
@property (nonatomic, assign) CGFloat fullWidth;
@property (nonatomic, assign) CGRect initialTopViewFrame;
@end

@implementation MEDynamicTransition

#pragma mark - ECSlidingViewControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)slidingViewController:(ECSlidingViewController *)slidingViewController
                                   animationControllerForOperation:(ECSlidingViewControllerOperation)operation
                                                 topViewController:(UIViewController *)topViewController {
    return self.defaultAnimationController;
}

- (id<UIViewControllerInteractiveTransitioning>)slidingViewController:(ECSlidingViewController *)slidingViewController
                          interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>)animationController {
    self.slidingViewController = slidingViewController;
    return self;
}

#pragma mark - Properties

- (ECSlidingAnimationController *)defaultAnimationController {
    if (_defaultAnimationController) return _defaultAnimationController;
    
    _defaultAnimationController = [[ECSlidingAnimationController alloc] init];
    
    return _defaultAnimationController;
}

- (UIDynamicAnimator *)animator {
    if (_animator) return _animator;
    
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.slidingViewController.view];
    _animator.delegate = self;
    
    return _animator;
}

- (UICollisionBehavior *)collisionBehavior {
    if (_collisionBehavior) return _collisionBehavior;
    
    _collisionBehavior = [[UICollisionBehavior alloc] initWithItems:@[self.slidingViewController.topViewController.view]];
    
    CGFloat containerHeight = self.slidingViewController.view.bounds.size.height;
    CGFloat containerWidth  = self.slidingViewController.view.bounds.size.width;
    CGFloat revealAmount    = self.slidingViewController.anchorRightRevealAmount;
    
    [_collisionBehavior addBoundaryWithIdentifier:@"LeftEdge" fromPoint:CGPointMake(-1, 0) toPoint:CGPointMake(-1, containerHeight)];
    [_collisionBehavior addBoundaryWithIdentifier:@"RightEdge" fromPoint:CGPointMake(revealAmount + containerWidth + 1, 0) toPoint:CGPointMake(revealAmount + containerWidth + 1, containerHeight)];

    return _collisionBehavior;
}

- (UIAttachmentBehavior *)attachmentBehavior {
    if (_attachmentBehavior) return _attachmentBehavior;
    
    _attachmentBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.slidingViewController.topViewController.view attachedToAnchor:CGPointZero];
    _attachmentBehavior.damping   = 1.0;
    _attachmentBehavior.frequency = 3.5;
    _attachmentBehavior.length    = 0;
    
    return _attachmentBehavior;
}

- (UIPushBehavior *)pushBehavior {
    if (_pushBehavior) return _pushBehavior;
    
    _pushBehavior = [[UIPushBehavior alloc] initWithItems:@[self.slidingViewController.topViewController.view] mode:UIPushBehaviorModeInstantaneous];
    
    return _pushBehavior;
}

- (UIDynamicBehavior *)compositeBehavior {
    if (_compositeBehavior) return _compositeBehavior;
    
    _compositeBehavior = [[UIDynamicBehavior alloc] init];
    [_compositeBehavior addChildBehavior:self.collisionBehavior];
    [_compositeBehavior addChildBehavior:self.attachmentBehavior];
    [_compositeBehavior addChildBehavior:self.pushBehavior];
    
    return _compositeBehavior;
}

#pragma mark - UIViewControllerInteractiveTransitioning

- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    self.transitionContext = transitionContext;
    
    UIViewController *topViewController = [transitionContext viewControllerForKey:ECTransitionContextTopViewControllerKey];
    topViewController.view.userInteractionEnabled = NO;
    
    if (_isInteractive) {
        UIViewController *underViewController = [transitionContext viewControllerForKey:ECTransitionContextUnderLeftControllerKey];
        CGRect underViewInitialFrame = [transitionContext initialFrameForViewController:underViewController];
        UIView *containerView = [transitionContext containerView];
        CGFloat finalLeftEdge = CGRectGetMinX([transitionContext finalFrameForViewController:topViewController]);
        CGFloat initialLeftEdge = CGRectGetMinX([transitionContext initialFrameForViewController:topViewController]);
        CGFloat fullWidth = fabsf(finalLeftEdge - initialLeftEdge);
        
        underViewController.view.frame = underViewInitialFrame;
        [containerView insertSubview:underViewController.view belowSubview:topViewController.view];
        
        self.positiveLeftToRight = initialLeftEdge < finalLeftEdge;
        self.fullWidth           = fullWidth;
    } else {
        [self.defaultAnimationController animateTransition:transitionContext];
    }
}

#pragma mark - UIPanGestureRecognizer action

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    UIView *topView       = self.slidingViewController.topViewController.view;
    CGFloat translationX  = [recognizer translationInView:self.slidingViewController.view].x;
    CGFloat velocityX     = [recognizer velocityInView:self.slidingViewController.view].x;

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            BOOL isMovingRight = velocityX > 0;
            
            CALayer *presentationLayer = (CALayer *)topView.layer.presentationLayer;
            self.initialTopViewFrame = presentationLayer.frame;

            _isInteractive = YES;
            
            if (self.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionCentered && isMovingRight && self.slidingViewController.underLeftViewController) {
                [self.slidingViewController anchorTopViewToRightAnimated:YES];
            } else if (self.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionCentered && !isMovingRight && self.slidingViewController.underRightViewController) {
                [self.slidingViewController anchorTopViewToLeftAnimated:YES];
            } else if (self.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredLeft) {
                [self.slidingViewController resetTopViewAnimated:YES];
            } else if (self.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionAnchoredRight) {
                [self.slidingViewController resetTopViewAnimated:YES];
            } else {
                _isInteractive = NO;
            }
            
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!_isInteractive) return;
            
            _collisionBehavior = nil;
            _attachmentBehavior = nil;
            _pushBehavior = nil;
            _compositeBehavior = nil;
            _animator = nil;
            
            CGRect topViewInitialFrame = self.initialTopViewFrame;
            CGFloat newLeftEdge = topViewInitialFrame.origin.x + translationX;
            
            if (newLeftEdge < 0) {
                newLeftEdge = 0;
            }
            
            topViewInitialFrame.origin.x = newLeftEdge;
            topView.frame = topViewInitialFrame;
            
            if (!self.positiveLeftToRight) translationX = translationX * -1.0;
            CGFloat percentComplete = (translationX / self.fullWidth);
            if (percentComplete < 0) percentComplete = 0;
            if (percentComplete > 100) percentComplete = 100;
            [self.transitionContext updateInteractiveTransition:percentComplete];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!_isInteractive) return;
            
            _isInteractive = NO;
            
            self.isPanningRight = velocityX > 0;
            
            CGFloat containerWidth = self.slidingViewController.view.bounds.size.width;
            CGFloat revealAmount   = self.slidingViewController.anchorRightRevealAmount;
            
            CGPoint anchorPoint = self.isPanningRight ? CGPointMake((containerWidth / 2) + revealAmount, topView.center.y) : CGPointMake((containerWidth / 2), topView.center.y);
            
            [self.animator updateItemUsingCurrentState:self.slidingViewController.topViewController.view];
            
            self.attachmentBehavior.anchorPoint = anchorPoint;
            
            self.pushBehavior.angle = 0; // velocity may be negative
            self.pushBehavior.magnitude = velocityX;
            self.pushBehavior.active = YES;
            
            [self.animator addBehavior:self.compositeBehavior];
            
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIDynamicAnimatorDelegate

- (void)dynamicAnimatorDidPause:(UIDynamicAnimator*)animator {
    if ((self.isPanningRight && self.positiveLeftToRight) || (!self.isPanningRight && !self.positiveLeftToRight)) {
        [self.transitionContext finishInteractiveTransition];
    } else if ((self.isPanningRight && !self.positiveLeftToRight) || (!self.isPanningRight && self.positiveLeftToRight)) {
        [self.transitionContext cancelInteractiveTransition];
    }
    
    _collisionBehavior = nil;
    _attachmentBehavior = nil;
    _pushBehavior = nil;
    _compositeBehavior = nil;
    _animator = nil;
    
    self.slidingViewController.topViewController.view.userInteractionEnabled = YES;
    
    [self.transitionContext completeTransition:YES];
}

@end
