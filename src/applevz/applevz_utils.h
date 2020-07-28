/*
 * applevz_utils.h: core driver functions for managing
 *                  Apple Virtualization.framework guests
 *
 * Copyright (C) 2020 Roman Bolshakov
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; If not, see
 * <http://www.gnu.org/licenses/>.
 *
 */

#pragma once

#include <Virtualization/Virtualization.h>

#include "datatypes.h"
#include "virdomainobjlist.h"
#include "conf/domain_event.h"

#define VIR_FROM_THIS VIR_FROM_APPLEVZ

struct _applevzDriver {
    virObjectLockable parent;

    /* Immutable pointer, self-locking APIs */
    virDomainObjListPtr domains;
    /*
    unsigned char session_uuid[VIR_UUID_BUFLEN];
    PRL_HANDLE server;
    virCapsPtr caps;
    */
    virDomainXMLOptionPtr xmlopt;
    virObjectEventStatePtr domainEventState;
    /*
    virSysinfoDefPtr hostsysinfo;
    unsigned long vzVersion;
    vzCapabilities vzCaps;
    */
};

typedef struct _applevzDriver applevzDriver;
typedef struct _applevzDriver *applevzDriverPtr;

struct _applevzConn {
    struct _applevzConn* next;

    applevzDriverPtr driver;
    /* Immutable pointer, self-locking APIs */
    virConnectCloseCallbackDataPtr closeCallback;
};

typedef struct _applevzConn applevzConn;
typedef struct _applevzConn *applevzConnPtr;

struct applevzDomObj {
    /*
    int id;
    */
    VZVirtualMachine *vzvm;
    /*
    PRL_HANDLE sdkdom;
    PRL_HANDLE stats;
    applevzDomainJobObj job;
    */
};

typedef struct applevzDomObj *applevzDomObjPtr;

void* applevzDomObjAlloc(void *opaque);
void applevzDomObjFree(void *p);

virDomainObjPtr applevzDomObjFromDomain(virDomainPtr domain);

applevzDriverPtr
applevzGetDriverConnection(void);
