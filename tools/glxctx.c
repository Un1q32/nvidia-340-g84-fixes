#include <X11/Xlib.h>
#include <GL/glx.h>
#include <GL/gl.h>
#include <stdio.h>

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) { printf("no display\n"); return 1; }
    int s = DefaultScreen(d);
    int attrs[] = { GLX_RGBA, GLX_DOUBLEBUFFER, GLX_DEPTH_SIZE, 24, None };
    XVisualInfo *vi = glXChooseVisual(d, s, attrs);
    if (!vi) { printf("no visual\n"); return 1; }
    GLXContext ctx = glXCreateContext(d, vi, NULL, True);
    if (!ctx) { printf("no context\n"); return 1; }
    Window root = RootWindow(d, s);
    XSetWindowAttributes swa;
    swa.colormap = XCreateColormap(d, root, vi->visual, AllocNone);
    swa.event_mask = ExposureMask;
    Window win = XCreateWindow(d, root, 0, 0, 100, 100, 0, vi->depth,
                               InputOutput, vi->visual,
                               CWColormap | CWEventMask, &swa);
    XMapWindow(d, win);
    XSync(d, False);
    if (!glXMakeCurrent(d, win, ctx)) { printf("makecurrent failed\n"); return 1; }
    printf("RENDERER=%s\n", (const char *) glGetString(GL_RENDERER));
    printf("VERSION=%s\n", (const char *) glGetString(GL_VERSION));
    printf("VENDOR=%s\n", (const char *) glGetString(GL_VENDOR));
    return 0;
}
