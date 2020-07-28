/*
 * applevz_driver.m: core driver functions for managing
 *                   Apple Virtualization.framework guests
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
 * License along with this library.  If not, see
 * <http://www.gnu.org/licenses/>.
 */

#include <config.h>

#include "configmake.h"
#include "datatypes.h"
#include "domain_conf.h"
#include "viraccessapicheck.h"
#include "viralloc.h"
#include "virerror.h"
#include "virfile.h"
#include "virpidfile.h"

#include "applevz.h"
#include "applevz_domain.h"
#include "applevz_driver.h"
#include "applevz_utils.h"

#define APPLEVZ_CONFIGDIR       SYSCONFDIR "/libvirt/applevz"
#define APPLEVZ_STATEDIR        RUNSTATEDIR "/libvirt/applevz"
#define APPLEVZ_LOGDIR          LOCALSTATEDIR "/log/libvirt/applevz"

static virClassPtr applevzDriverClass;

/* pid file FD, ensures two copies of the driver can't use the same root */
static int applevz_driver_lock_fd = -1;
static virMutex applevz_driver_lock;
static applevzDriverPtr applevz_driver;
static applevzConnPtr applevz_conn_list;

static virDrvOpenStatus
applevzConnectOpen(virConnectPtr conn G_GNUC_UNUSED,
                   virConnectAuthPtr auth G_GNUC_UNUSED,
                   virConfPtr conf G_GNUC_UNUSED,
                   unsigned int flags G_GNUC_UNUSED)
{
    applevzDriverPtr driver = NULL;
    applevzConnPtr privconn = NULL;

    /*
    virCheckFlags(VIR_CONNECT_RO, VIR_DRV_OPEN_ERROR);
    */

    /* From this point on, the connection is for us. */
    /*
    if (STRNEQ(conn->uri->path, "/system")) {
        virReportError(VIR_ERR_INTERNAL_ERROR,
                       _("Unexpected Virtuozzo URI path '%s', try vz:///system"),
                       conn->uri->path);
        return VIR_DRV_OPEN_ERROR;
    }
    */

    if (virConnectOpenEnsureACL(conn) < 0)
        return VIR_DRV_OPEN_ERROR;

    if (!(driver = applevzGetDriverConnection()))
        return VIR_DRV_OPEN_ERROR;

    if (VIR_ALLOC(privconn) < 0)
        goto error;

    conn->privateData = privconn;
    privconn->driver = driver;

    if (!(privconn->closeCallback = virNewConnectCloseCallbackData()))
        goto error;

    virMutexLock(&applevz_driver_lock);
    privconn->next = applevz_conn_list;
    applevz_conn_list = privconn;
    virMutexUnlock(&applevz_driver_lock);

    return VIR_DRV_OPEN_SUCCESS;

 error:

    conn->privateData = NULL;
    virObjectUnref(driver);
    VIR_FREE(privconn);
    return VIR_DRV_OPEN_ERROR;
}

static int applevzConnectClose(virConnectPtr conn G_GNUC_UNUSED)
{
    return 0;
}

static int
applevzConnectListDomains(virConnectPtr conn, int *ids, int maxids)
{
    applevzConnPtr privconn = conn->privateData;

    if (virConnectListDomainsEnsureACL(conn) < 0)
        return -1;

    return virDomainObjListGetActiveIDs(privconn->driver->domains, ids,
                                        maxids, virConnectListDomainsCheckACL,
                                        conn);
}

static int
applevzConnectNumOfDomains(virConnectPtr conn)
{
    applevzConnPtr privconn = conn->privateData;

    if (virConnectNumOfDomainsEnsureACL(conn) < 0)
        return -1;

    return virDomainObjListNumOfDomains(privconn->driver->domains, true,
                                        virConnectNumOfDomainsCheckACL, conn);
}

static int
applevzConnectListDefinedDomains(virConnectPtr conn, char **const names,
                                 int maxnames)
{
    applevzConnPtr privconn = conn->privateData;

    if (virConnectListDefinedDomainsEnsureACL(conn) < 0)
        return -1;

    memset(names, 0, sizeof(*names) * maxnames);
    return virDomainObjListGetInactiveNames(privconn->driver->domains, names,
                                            maxnames,
                                            virConnectListDefinedDomainsCheckACL,
                                            conn);
}

static int
applevzConnectNumOfDefinedDomains(virConnectPtr conn)
{
    applevzConnPtr privconn = conn->privateData;

    if (virConnectNumOfDefinedDomainsEnsureACL(conn) < 0)
        return -1;

    return virDomainObjListNumOfDomains(privconn->driver->domains, false,
                                        virConnectNumOfDefinedDomainsCheckACL,
                                        conn);
}

static int
applevzConnectListAllDomains(virConnectPtr conn,
                             virDomainPtr **domains,
                             unsigned int flags)
{
    applevzConnPtr privconn = conn->privateData;

    virCheckFlags(VIR_CONNECT_LIST_DOMAINS_FILTERS_ALL, -1);

    if (virConnectListAllDomainsEnsureACL(conn) < 0)
        return -1;

    return virDomainObjListExport(privconn->driver->domains, conn, domains,
                                  virConnectListAllDomainsCheckACL, flags);
}

static int
applevzDomainCreateWithFlags(virDomainPtr domain, unsigned int flags)
{
    /*
    applevzConnPtr privconn = domain->conn->privateData;
    */
    virDomainObjPtr dom;
    int ret = -1;
    /*
    bool job = false;
    */

    virCheckFlags(0, -1);

    if (!(dom = applevzDomObjFromDomain(domain)))
        return -1;

    if (virDomainCreateWithFlagsEnsureACL(domain->conn, dom->def) < 0)
        goto cleanup;

    /*
    if (vzDomainObjBeginJob(dom) < 0)
        goto cleanup;
    job = true;

    if (vzEnsureDomainExists(dom) < 0)
        goto cleanup;
    */

    if (applevzStart(dom) < 0)
        goto cleanup;

    /*
    if (prlsdkUpdateDomain(privconn->driver, dom) < 0)
        goto cleanup;
    */

    ret = 0;

 cleanup:
    /*
    if (job)
        vzDomainObjEndJob(dom);
    */
    virDomainObjEndAPI(&dom);

    return ret;
}

static int
applevzDomainCreate(virDomainPtr domain)
{
    return applevzDomainCreateWithFlags(domain, 0);
}

static virDomainPtr
applevzDomainLookupByID(virConnectPtr conn, int id)
{
    applevzConnPtr privconn = conn->privateData;
    virDomainPtr ret = NULL;
    virDomainObjPtr dom;

    dom = virDomainObjListFindByID(privconn->driver->domains, id);

    if (dom == NULL) {
        virReportError(VIR_ERR_NO_DOMAIN, NULL);
        return NULL;
    }

    if (virDomainLookupByIDEnsureACL(conn, dom->def) < 0)
        goto cleanup;

    ret = virGetDomain(conn, dom->def->name, dom->def->uuid, dom->def->id);

 cleanup:
    virDomainObjEndAPI(&dom);
    return ret;
}

static virDomainPtr
applevzDomainLookupByUUID(virConnectPtr conn, const unsigned char *uuid)
{
    applevzConnPtr privconn = conn->privateData;
    virDomainPtr ret = NULL;
    virDomainObjPtr dom;

    dom = virDomainObjListFindByUUID(privconn->driver->domains, uuid);

    if (dom == NULL) {
        char uuidstr[VIR_UUID_STRING_BUFLEN];
        virUUIDFormat(uuid, uuidstr);
        virReportError(VIR_ERR_NO_DOMAIN,
                       _("no domain with matching uuid '%s'"), uuidstr);
        return NULL;
    }

    if (virDomainLookupByUUIDEnsureACL(conn, dom->def) < 0)
        goto cleanup;

    ret = virGetDomain(conn, dom->def->name, dom->def->uuid, dom->def->id);

 cleanup:
    virDomainObjEndAPI(&dom);
    return ret;
}

static virDomainPtr
applevzDomainLookupByName(virConnectPtr conn, const char *name)
{
    applevzConnPtr privconn = conn->privateData;
    virDomainPtr ret = NULL;
    virDomainObjPtr dom;

    dom = virDomainObjListFindByName(privconn->driver->domains, name);

    if (dom == NULL) {
        virReportError(VIR_ERR_NO_DOMAIN,
                       _("no domain with matching name '%s'"), name);
        return NULL;
    }

    if (virDomainLookupByNameEnsureACL(conn, dom->def) < 0)
        goto cleanup;

    ret = virGetDomain(conn, dom->def->name, dom->def->uuid, dom->def->id);

 cleanup:
    virDomainObjEndAPI(&dom);
    return ret;
}

static virDomainPtr
applevzDomainDefineXMLFlags(virConnectPtr conn,
                            const char *xml G_GNUC_UNUSED,
                            unsigned int flags)
{
    applevzConnPtr privconn = conn->privateData;
    virDomainPtr dom = NULL;
    virDomainDefPtr def = NULL;
    virDomainDefPtr oldDef = NULL;
    virDomainObjPtr vm = NULL;
    virObjectEventPtr event = NULL;
    //virCapsPtr caps = NULL;
    unsigned int parse_flags = VIR_DOMAIN_DEF_PARSE_INACTIVE;

    virCheckFlags(VIR_DOMAIN_DEFINE_VALIDATE, NULL);

    if (flags & VIR_DOMAIN_DEFINE_VALIDATE)
        parse_flags |= VIR_DOMAIN_DEF_PARSE_VALIDATE_SCHEMA;

    ////caps = bhyveDriverGetCapabilities(privconn);
    ////if (!caps)
    ////    return NULL;

    if ((def = virDomainDefParseString(xml, privconn->driver->xmlopt,
                                       NULL, parse_flags)) == NULL)
        goto cleanup;

    if (virXMLCheckIllegalChars("name", def->name, "\n") < 0)
        goto cleanup;

    if (virDomainDefineXMLFlagsEnsureACL(conn, def) < 0)
        goto cleanup;

    if (!(vm = virDomainObjListAdd(privconn->driver->domains, def,
    				privconn->driver->xmlopt,
    				0, &oldDef)))
    	goto cleanup;
    def = NULL;
    vm->persistent = 1;

    if (virDomainDefSave(vm->newDef ? vm->newDef : vm->def,
    			privconn->driver->xmlopt, APPLEVZ_CONFIGDIR) < 0) {
    	virDomainObjListRemove(privconn->driver->domains, vm);
    	goto cleanup;
    }

    event = virDomainEventLifecycleNewFromObj(vm,
                                              VIR_DOMAIN_EVENT_DEFINED,
                                              !oldDef ?
                                              VIR_DOMAIN_EVENT_DEFINED_ADDED :
                                              VIR_DOMAIN_EVENT_DEFINED_UPDATED);

 cleanup:
    //virObjectUnref(caps);
    virDomainDefFree(def);
    virDomainDefFree(oldDef);
    virDomainObjEndAPI(&vm);
    virObjectEventStateQueue(privconn->driver->domainEventState, event);

    return dom;
}

static virDomainPtr
applevzDomainDefineXML(virConnectPtr conn, const char *xml)
{
    return applevzDomainDefineXMLFlags(conn, xml, 0);
}

static virDomainXMLPrivateDataCallbacks applevzDomainXMLPrivateDataCallbacksPtr = {
    .alloc = applevzDomObjAlloc,
    .free = applevzDomObjFree,
};

static virDomainDefParserConfig applevzDomainDefParserConfig = {
    /*
    .macPrefix = {0x42, 0x1C, 0x00},
    .domainPostParseCallback = vzDomainDefPostParse,
    .devicesPostParseCallback = vzDomainDeviceDefPostParse,
    .domainValidateCallback = vzDomainDefValidate,
    .deviceValidateCallback = vzDomainDeviceDefValidate,
    */
};

static void
applevzDriverDispose(void *obj)
{
    applevzDriverPtr driver = obj;

    /*
    vboxDriverDisposed = true;
    virObjectUnref(driver->caps);
    */
    virObjectUnref(driver->xmlopt);
}

static int applevzDriverOnceInit(void)
{
    if (!VIR_CLASS_NEW(applevzDriver, virClassForObjectLockable()))
        return -1;

    return 0;
}

VIR_ONCE_GLOBAL_INIT(applevzDriver);

static applevzDriverPtr
applevzDriverObjNew(void)
{
    applevzDriverPtr driver;

    if (applevzDriverInitialize() < 0)
        return NULL;

    if (!(driver = virObjectLockableNew(applevzDriverClass)))
        return NULL;

    /*
    vzDomainDefParserConfig.priv = driver;

    if (!(driver->caps = vzBuildCapabilities()) ||
    */
    if (
        !(driver->xmlopt = virDomainXMLOptionNew(&applevzDomainDefParserConfig,
                                                 &applevzDomainXMLPrivateDataCallbacksPtr,
                                                 NULL, NULL, NULL)) ||
        !(driver->domains = virDomainObjListNew()) ||
        !(driver->domainEventState = virObjectEventStateNew()) ||
        false ) {
	/*
        (vzInitVersion(driver) < 0) ||
        (prlsdkConnect(driver) < 0)) {
	*/
        virObjectUnref(driver);
        return NULL;
    }

    /*
    driver->hostsysinfo = virSysinfoRead();
    ignore_value(prlsdkLoadDomains(driver));
    */

    /* As far as waitDomainJob finally calls virReportErrorHelper
     * and we are not going to report it, reset it explicitly */
    virResetLastError();

    return driver;
}

applevzDriverPtr
applevzGetDriverConnection(void)
{
    /*
    if (!applevz_driver_privileged) {
        virReportError(VIR_ERR_INTERNAL_ERROR,
                       "%s", _("applevz state driver is not active"));
        return NULL;
    }
    */
    virMutexLock(&applevz_driver_lock);
    if (!applevz_driver)
        applevz_driver = applevzDriverObjNew();
    virObjectRef(applevz_driver);
    virMutexUnlock(&applevz_driver_lock);

    return applevz_driver;
}

static int
applevzStateCleanup(void)
{
    virObjectUnref(applevz_driver);
    applevz_driver = NULL;
    if (applevz_driver_lock_fd != -1)
        virPidFileRelease(APPLEVZ_STATEDIR, "driver", applevz_driver_lock_fd);
    virMutexDestroy(&applevz_driver_lock);
    return 0;
}

static int
applevzStateInitialize(bool privileged G_GNUC_UNUSED,
                       const char *root G_GNUC_UNUSED,
                       virStateInhibitCallback callback G_GNUC_UNUSED,
                       void *opaque G_GNUC_UNUSED)
{
    if (virFileMakePathWithMode(APPLEVZ_STATEDIR, S_IRWXU) < 0) {
        virReportSystemError(errno, _("cannot create state directory '%s'"),
                             APPLEVZ_STATEDIR);
        return VIR_DRV_STATE_INIT_ERROR;
    }

    if ((applevz_driver_lock_fd =
         virPidFileAcquire(APPLEVZ_STATEDIR, "driver", false, getpid())) < 0)
        return VIR_DRV_STATE_INIT_ERROR;

    if (virMutexInit(&applevz_driver_lock) < 0)
        goto error;

    /* Failing to create driver here is not fatal and only means
     * that next driver client will try once more when connecting */
    applevz_driver = applevzDriverObjNew();
    return VIR_DRV_STATE_INIT_COMPLETE;

 error:
    applevzStateCleanup();
    return VIR_DRV_STATE_INIT_ERROR;
    return 0;
}

static virHypervisorDriver applevzHypervisorDriver = {
    .name = "applevz",
    //.connectURIProbe = vboxConnectURIProbe,
    .connectOpen = applevzConnectOpen,
    .connectClose = applevzConnectClose,
    .connectListDomains = applevzConnectListDomains,
    .connectNumOfDomains = applevzConnectNumOfDomains,
    .connectListDefinedDomains = applevzConnectListDefinedDomains,
    .connectNumOfDefinedDomains = applevzConnectNumOfDefinedDomains,
    .connectListAllDomains = applevzConnectListAllDomains,
    .domainLookupByID = applevzDomainLookupByID,
    .domainLookupByUUID = applevzDomainLookupByUUID,
    .domainLookupByName = applevzDomainLookupByName,
    .domainDefineXML = applevzDomainDefineXML,
    .domainCreate = applevzDomainCreate,
    .domainCreateWithFlags = applevzDomainCreateWithFlags,
};

static virConnectDriver applevzConnectDriver = {
    .localOnly = true,
    .uriSchemes = (const char *[]){ "applevz", NULL },
    .hypervisorDriver = &applevzHypervisorDriver,
};

static virStateDriver applevzStateDriver = {
    .name = "applevz",
    .stateInitialize = applevzStateInitialize,
    .stateCleanup = applevzStateCleanup,
};

int
applevzRegister(void)
{
    if (virRegisterConnectDriver(&applevzConnectDriver, false) < 0)
        return -1;
    if (virRegisterStateDriver(&applevzStateDriver) < 0)
        return -1;
    return 0;
}
