/*
 * ut-profile-init -- create the Firefox profile directory for the click app.
 *
 * Exists purely because click AppArmor confinement gives the launcher no way to
 * make a directory: there is no general exec rule for /usr/bin, so mkdir(1) fails
 * with "Permission denied", and the shell has no built-in for it. Anything
 * inside the click payload may be executed, so this ships alongside the
 * launcher.
 *
 * Why the profile has to be pinned:
 *
 *   Left to itself Gecko picks a profile via profiles.ini/installs.ini, keyed
 *   on the *install path* -- which for a click contains the version. Every
 *   upgrade therefore looks like a new installation and silently starts a fresh
 *   profile, losing bookmarks, history and window geometry. Stale lock files
 *   from unclean exits cause the same thing without any version change; that
 *   produced seven abandoned profiles in a single afternoon of testing.
 *
 *   Passing --profile <fixed path> avoids all of it, but --profile does not
 *   create a missing directory: Gecko fails and puts up a modal error dialog
 *   instead of a browser window. Hence this helper.
 *
 * It also seeds xulstore.json on first run so the window starts maximized at
 * the origin. Without it Gecko can restore an off-screen position (a stored
 * screenX of -90 was hanging the window off the display) and Lomiri does not
 * constrain window placement.
 *
 * Usage: ut-profile-init <profile-dir>
 *
 * Copyright (C) 2026 Hans Kramer
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version. See the LICENSE file for the full text.
 */

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static int mkdir_p(const char *path)
{
    char buf[4096];
    size_t len = strlen(path);

    if (len == 0 || len >= sizeof(buf)) {
        return -1;
    }
    memcpy(buf, path, len + 1);

    for (char *p = buf + 1; *p; p++) {
        if (*p != '/') {
            continue;
        }
        *p = '\0';
        if (mkdir(buf, 0700) != 0 && errno != EEXIST) {
            return -1;
        }
        *p = '/';
    }
    if (mkdir(buf, 0700) != 0 && errno != EEXIST) {
        return -1;
    }
    return 0;
}

/* Full screen at the origin. Gecko rewrites this as the user resizes; it only
 * has to be right the first time, before any geometry has been stored. */
static const char kXulstore[] =
    "{\"chrome://browser/content/browser.xhtml\":{\"main-window\":"
    "{\"sizemode\":\"maximized\",\"screenX\":\"0\",\"screenY\":\"0\"}}}\n";

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s <profile-dir>\n", argv[0]);
        return 1;
    }

    if (mkdir_p(argv[1]) != 0) {
        fprintf(stderr, "ut-profile-init: cannot create %s: %s\n", argv[1],
                strerror(errno));
        return 1;
    }

    char path[4096];
    if ((size_t)snprintf(path, sizeof(path), "%s/xulstore.json", argv[1]) >=
        sizeof(path)) {
        return 1;
    }

    if (access(path, F_OK) == 0) {
        return 0;
    }

    FILE *f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "ut-profile-init: cannot write %s: %s\n", path,
                strerror(errno));
        return 1;
    }
    fputs(kXulstore, f);
    fclose(f);

    return 0;
}
