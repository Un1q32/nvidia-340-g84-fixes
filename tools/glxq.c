#include <X11/Xlib.h>
#include <GL/glx.h>
#include <stdio.h>

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) { printf("no display\n"); return 1; }
    int screen = DefaultScreen(d);
    int op = 0, ev = 0, er = 0;
    int ok = XQueryExtension(d, "GLX", &op, &ev, &er);
    printf("GLX_ext=%d op=%d ev=%d err=%d\n", ok, op, ev, er);
    int maj = -1, min = -1;
    int vok = glXQueryVersion(d, &maj, &min);
    printf("glXQueryVersion ok=%d %d.%d\n", vok, maj, min);
    printf("client_vendor=%s\n", glXGetClientString(d, GLX_VENDOR));
    const char *sv = glXQueryServerString(d, screen, GLX_VENDOR);
    const char *sver = glXQueryServerString(d, screen, GLX_VERSION);
    printf("server_vendor=%s\n", sv ? sv : "(null)");
    printf("server_version=%s\n", sver ? sver : "(null)");
    int n = -1;
    GLXFBConfig *f = glXGetFBConfigs(d, screen, &n);
    printf("getfbconfigs n=%d ptr=%p\n", n, (void *)f);
    int n2 = -1;
    GLXFBConfig *f2 = glXChooseFBConfig(d, screen, NULL, &n2);
    printf("choosefbconfig n=%d ptr=%p\n", n2, (void *)f2);
    int attrs[] = { GLX_RGBA, GLX_DOUBLEBUFFER, None };
    XVisualInfo *vi = glXChooseVisual(d, screen, attrs);
    printf("choosevisual=%p\n", (void *)vi);
    return 0;
}
