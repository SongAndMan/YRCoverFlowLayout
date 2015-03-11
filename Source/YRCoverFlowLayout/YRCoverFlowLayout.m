//
//  CoverFlowLayout.m
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Yuri R.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "YRCoverFlowLayout.h"

@implementation YRCoverFlowLayout

#pragma mark - Init

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        [self commonInit];
    }
    
    return self;
}

#pragma mark - Overridden

- (void)prepareLayout {
    [super prepareLayout];
    
    NSAssert(self.collectionView.numberOfSections == 1, @"[CoverFlowLayout]: Multiple sections aren't supported!");
    NSAssert(self.scrollDirection == UICollectionViewScrollDirectionHorizontal, @"[CoverFlowLayout]: Vertical scrolling isn't supported!");
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    CGFloat xOffset = self.collectionView.contentOffset.x;
    NSArray *idxPaths = [self indexPathsContainedInRect:rect];
//    CGRect visibleRect = (CGRect){self.collectionView.contentOffset, self.collectionView.bounds.size};
    
//    NSLog(@"Current offset: %.2f.", xOffset);
//    NSLog(@"Visible rect: %@. Requested rect: %@", NSStringFromCGRect(visibleRect), NSStringFromCGRect(rect));
//    NSLog(@"Got %d items for requested rect.", (int32_t)idxPaths.count);
    
    NSMutableArray *resultingAttributes = [NSMutableArray new];
    
    for (NSIndexPath *path in idxPaths) {
        UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:path];
        
        // Calculate center:
        // Interpolate offset for given attribute. For this task we need min max interval and min and max x allowed for item.
        CGFloat minInterval = (path.row - 1) * [self collectionViewWidth];
        CGFloat maxInterval = (path.row + 1) * [self collectionViewWidth];
        
        CGFloat minX = [self minXForRow:path.row];
        CGFloat maxX = [self maxXForRow:path.row] - self.itemSize.width;
        
        // Interpolate by formula
        CGFloat interpolatedX = MIN(MAX(minX + (((maxX - minX) / (maxInterval - minInterval)) * (xOffset - minInterval)),
                                        minX),
                                    maxX);
        attributes.center = (CGPoint){interpolatedX + self.itemSize.width / 2,
                                      attributes.center.y};
        
        // Calculate position of current attributes in range (0, collection view width).
        CGFloat screenPosition = MIN(MAX(attributes.center.x - xOffset,
                                         0),
                                     [self collectionViewWidth]);

        // Interpolate position into angle by formula.
        CGFloat angle = self.maxCoverDegree - screenPosition * self.maxCoverDegree / ([self collectionViewWidth] / 2);
        
        CATransform3D transform = CATransform3DIdentity;
        // Add perspective.
        transform.m34 = -1 / 500.0f;
        // Then rotate.
        transform = CATransform3DRotate(transform, angle * M_PI / 180, 0, 1, 0);
        attributes.transform3D = transform;
        attributes.zIndex = NSIntegerMax - path.row;

//        NSLog(@"IDX: %d. Item position: %.2f. On-screen position: %.2f. Interpolated angle: %.2f",
//              (int32_t)attributes.indexPath.row,
//              attributes.center.x,
//              screenPosition,
//              angle);
        
        [resultingAttributes addObject:attributes];
    }
    
    return [NSArray arrayWithArray:resultingAttributes];
}

- (CGSize)collectionViewContentSize {
    return (CGSize){self.collectionView.bounds.size.width * [self.collectionView numberOfItemsInSection:0],
                    self.collectionView.bounds.size.height};
}

#pragma mark - Accessors

- (CGFloat)collectionViewWidth {
    return self.collectionView.bounds.size.width;
}

#pragma mark - Private

- (void)commonInit {
    self.maxCoverDegree = 45.0f;
    self.coverDensity = 0.25f;
}

- (CGPoint)itemCenterForRow:(NSInteger)row {
    CGSize collectionViewSize = self.collectionView.bounds.size;
    return (CGPoint){row * collectionViewSize.width + collectionViewSize.width / 2 ,
                    collectionViewSize.height / 2};
}

- (CGFloat)minXForRow:(NSInteger)row {
    return [self itemCenterForRow:row - 1].x + (1.0f / 2 - self.coverDensity) * self.itemSize.width;
}

- (CGFloat)maxXForRow:(NSInteger)row {
    return [self itemCenterForRow:row + 1].x - (1.0f / 2 - self.coverDensity) * self.itemSize.width;
}

- (NSArray *)indexPathsContainedInRect:(CGRect)rect {
    if ([self.collectionView numberOfItemsInSection:0] == 0) {
        // Nothing to do here when we don't have items.
        return @[];
    }
    
    // Find min and max rows that can be determined for sure.
    NSInteger minRow = MAX(rect.origin.x / [self collectionViewWidth], 0);
    NSInteger maxRow = CGRectGetMaxX(rect) / [self collectionViewWidth];
    
    // Additional check for rows that also can be included (our rows are moving depending on content size).
    NSInteger candidateMinRow = MAX(minRow - 1, 0);
    if ([self maxXForRow:candidateMinRow] >= rect.origin.x) {
        // We have a row that is lesser than given minimum.
        minRow = candidateMinRow;
    }
    
    NSInteger candidateMaxRow = MIN(maxRow + 1, [self.collectionView numberOfItemsInSection:0] - 1);
    if ([self minXForRow:candidateMaxRow] <= CGRectGetMaxX(rect)) {
        maxRow = candidateMaxRow;
    }
    
    // Simply add index paths between min and max.
    NSMutableArray *resultingIdxPaths = [NSMutableArray new];
    
    for (NSInteger i = minRow; i <= maxRow; i++) {
        [resultingIdxPaths addObject:[NSIndexPath indexPathForRow:i
                                                        inSection:0]];
    }
    
    return [NSArray arrayWithArray:resultingIdxPaths];
}

@end