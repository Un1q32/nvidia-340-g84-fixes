#include <X11/Xlib.h>
#include <GL/glx.h>
#include <stdio.h>

/* 32-bit GLX probe: build with
 *   gcc -m32 -O2 -o glxtest32 glxtest32.c -lGL -lX11
 * Requires the 32-bit X11 runtime (abi_x86_32). */

typedef const unsigned char *(*PFNGLGETSTRING)(unsigned int);

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) { puts("no display"); return 1; }
    int s = DefaultScreen(d);
    int attrs[] = { GLX_RGBA, GLX_DOUBLEBUFFER, GLX_DEPTH_SIZE, 24, None };
    XVisualInfo *vi = glXChooseVisual(d, s, attrs);
    if (!vi) { puts("no visual"); return 1; }
    GLXContext c = glXCreateContext(d, vi, NULL, True);
    if (!c) { puts("no context"); return 1; }
    Window root = RootWindow(d, s);
    XSetWindowAttributes swa;
    swa.colormap = XCreateColormap(d, root, vi->visual, AllocNone);
    swa.event_mask = ExposureMask;
    Window w = XCreateWindow(d, root, 0, 0, 100, 100, 0, vi->depth,
                             InputOutput, vi->visual,
                             CWColormap | CWEventMask, &swa);
    XMapWindow(d, w);
    XSync(d, False);
    if (!glXMakeCurrent(d, w, c)) { puts("makecurrent fail"); return 1; }

    PFNGLGETSTRING gs = (PFNGLGETSTRING) glXGetProcAddressARB(
        (const GLubyte *) "glGetString");
    if (!gs) { puts("no glGetString"); return 1; }
    printf("RENDERER=%s\n", gs(GL_RENDERER));
    printf("VERSION=%s\n", gs(GL_VERSION));
    printf("VENDOR=%s\n", gs(GL_VENDOR));
    return 0;
}
