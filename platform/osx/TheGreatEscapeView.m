//
//  TheGreatEscapeView.m
//  The Great Escape
//
//  Created by David Thomas on 11/10/2014.
//  Copyright (c) 2014 David Thomas. All rights reserved.
//

#import <ctype.h>

#import <pthread.h>

#import <Foundation/Foundation.h>

#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>

#import <GLUT/glut.h>

#import "ZXSpectrum/ZXSpectrum.h"
#import "TheGreatEscape/TheGreatEscape.h"

#import "speckey.h"

#import "TheGreatEscapeView.h"

// -----------------------------------------------------------------------------

// move this into state
static speckeyfield_t keys;

#pragma mark - UIView

@interface TheGreatEscapeView()
{
  ZXSpectrum_t *zx;
  tgestate_t   *game;
  
  unsigned int *pixels;
  float         scale;
  pthread_t     thread;
}

@end

// -----------------------------------------------------------------------------

@implementation TheGreatEscapeView

// -----------------------------------------------------------------------------

#pragma mark - Game thread callbacks

static void draw_handler(unsigned int *pixels, void *opaque)
{
  [(__bridge id) opaque setPixels:pixels];
}

static void sleep_handler(int duration, sleeptype_t sleeptype, void *opaque)
{
  usleep(duration); // duration is taken literally for now
}

static int key_handler(uint16_t port, void *opaque)
{
  return port_to_keyfield(port, keys);
}

// -----------------------------------------------------------------------------

#pragma mark - Game thread

static void *tge_thread(void *arg)
{
  tgestate_t *game = arg;
  
  tge_setup(game);

  for (;;) // while (!quit)
    tge_main(game);
  
  //tge_destroy(game);
  
  //ZXSpectrum_destroy(zx);
  
  return NULL;
}

// -----------------------------------------------------------------------------

#pragma mark - blah

- (void)setPixels:(unsigned int *)data
{
  pixels = data;
  [self setNeedsDisplayInRect:NSMakeRect(0, 0, 1000, 1000)];
}

- (void)awakeFromNib
{
  const ZXSpectrum_config_t zxconfig =
  {
    (__bridge void *)(self),
    &draw_handler,
    &sleep_handler,
    &key_handler,
  };

  /* Configuration of The Great Escape instance. */
  static const tgeconfig_t tgeconfig =
  {
    256 / 8,
    192 / 8
  };


  zx     = NULL;
  game   = NULL;
  pixels = NULL;
  scale  = 1.0f;


  NSWindow *w = [self window];

  /* Enforce a 4:3 aspect ratio for the window. */
  [w setContentAspectRatio:NSMakeSize(4.0, 3.0)];



  NSRect contentRect = NSMakeRect(0, 0, tgeconfig.width  * 8 * scale, tgeconfig.height * 8 * scale);

  [w setFrame:[w frameRectForContentRect:contentRect] display:YES];

  [self setFrame:NSMakeRect(0, 0, contentRect.size.width, contentRect.size.height)];


  zx = ZXSpectrum_create(&zxconfig);
  if (zx == NULL)
    goto failure;
  
  game = tge_create(zx, &tgeconfig);
  if (game == NULL)
    goto failure;
  
  pthread_create(&thread, NULL /* pthread_attr_t */, tge_thread, game);
  
  return;
  
  
failure:
  tge_destroy(game);
  ZXSpectrum_destroy(zx);
}

// -----------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)coder
{
  self = [super initWithCoder:coder];
  if (self) {
    [self prepare];
  }
  return self;
}

// -----------------------------------------------------------------------------

- (void)prepare
{
  NSLog(@"prepare");

  // The GL context must be active for these functions to have an effect
  [[self openGLContext] makeCurrentContext];
  
  // Configure the view
  glShadeModel(GL_FLAT); // Selects flat shading
  glDisable(GL_DEPTH_TEST); // Don't update the depth buffer.

  glMatrixMode(GL_PROJECTION); // Applies subsequent matrix operations to the projection matrix stack
  glLoadIdentity(); // Replace the current matrix with the identity matrix

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  //  glTranslatef(0.375, 0.375, 0);

  // Set up constant values
  glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
}

// -----------------------------------------------------------------------------

//- (void)animate
//{
//  /* redraw just the region we've invalidated */
//  [self setNeedsDisplayInRect:NSMakeRect(0, 0, 1000, 1000)];
//}

- (void)reshape
{
  // Convert up to window space, which is in pixel units.
  NSRect baseRect = [self convertRectToBacking:[self bounds]];

//  // Now the result is glViewport()-compatible.
//  glViewport(0, 0, (GLsizei) baseRect.size.width, (GLsizei) baseRect.size.height);

  GLsizei w,h;

  w = baseRect.size.width;
  h = baseRect.size.height;

  scale = (double) w / 256;

  glViewport(0, 0, w, h);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(0, w, 0, h, 0.1, 1);
  glPixelZoom(1, -1);
  glRasterPos3f(0, h - 1, -0.3);
}

// -----------------------------------------------------------------------------

//- (void)setTimer
//{
//  [NSTimer scheduledTimerWithTimeInterval:1.0 / 30 /* 30fps */
//                                   target:self
//                                 selector:@selector(onTick:)
//                                 userInfo:nil
//                                  repeats:YES];
//}
//
//- (void)onTick:(NSTimer *)timer
//{
//  (void) timer;
//
//  [self animate];
//}

// -----------------------------------------------------------------------------

- (void)drawRect:(NSRect)dirtyRect
{
  if (scale == 0.0f)
    return;

  float zsx =  scale;
  float zsy = -scale;

  (void) dirtyRect;

  // Clear the background
  // Do this every frame or you'll see junk in the border.
  glClear(GL_COLOR_BUFFER_BIT);

  if (pixels)
  {
    // Draw the image
    glPixelZoom(zsx, zsy);
    glDrawPixels(256, 192, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
  }
  
  // Flush to screen
  glFinish();
}

// -----------------------------------------------------------------------------

#pragma mark - Key handling

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  return YES;
}

- (IBAction)zoom:(id)sender
{
  NSInteger tag;
  NSSize    size;

  /* Menu tag is 1..4 for 1x..4x scale. */
  tag = [sender tag];
  if (tag < 1)
    tag = 1;
  else if (tag > 4)
    tag = 4;

  scale = 1.0f * tag;

  size.width  = 256 * scale; // FIXME: Pull these dimensions from somewhere central.
  size.height = 192 * scale;

  [[self window] setContentSize:size];

  [self setFrame:NSMakeRect(0, 0, size.width, size.height)];
}

- (void)keyDown:(NSEvent*)event
{
  NSEventModifierFlags  modifierFlags;
  NSString             *chars;

  modifierFlags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;
  if (modifierFlags != 0)
    return;

  chars = [event characters];
  if ([chars length] == 0)
    return;

  keys = set_speckey(keys, [chars characterAtIndex:0]);

  // NSLog(@"Key pressed: %@", event);
}

- (void)keyUp:(NSEvent*)event
{
  NSEventModifierFlags  modifierFlags;
  NSString             *chars;

  modifierFlags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;
  if (modifierFlags != 0)
    return;

  chars = [event characters];
  if ([chars length] == 0)
    return;

  keys = clear_speckey(keys, [chars characterAtIndex:0]);

  // NSLog(@"Key released: %@", event);
}

- (void)flagsChanged:(NSEvent*)event
{
  /* Unlike keyDown and keyUp, flagsChanged is a single event delivered when any
   * one of the modifier key states change, down or up. */

  bool shift = ([event modifierFlags] & NSShiftKeyMask) != 0;
  bool alt   = ([event modifierFlags] & NSAlternateKeyMask) != 0;

  /* For reference:
   *
   * bool control = ([event modifierFlags] & NSControlKeyMask) != 0;
   * bool command = ([event modifierFlags] & NSCommandKeyMask) != 0;
   */

  keys = assign_speckey(keys, speckey_CAPS_SHIFT,   shift);
  keys = assign_speckey(keys, speckey_SYMBOL_SHIFT, alt);

  // NSLog(@"Key shift=%d control=%d alt=%d command=%d", shift, control, alt, command);
}

// -----------------------------------------------------------------------------

@end
