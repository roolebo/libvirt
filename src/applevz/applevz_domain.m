/*
 * applevz_domain.m: applvz domain private state headers
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

/*
#include "configmake.h"
*/
/*
#include "viraccessapicheck.h"
#include "viralloc.h"
#include "virerror.h"
#include "virfile.h"
#include "virpidfile.h"
*/

#include "applevz_utils.h"
#include "applevz_domain.h"

virDomainObjPtr
applevzDomObjFromDomain(virDomainPtr domain)
{
    virDomainObjPtr vm;
    applevzConnPtr privconn = domain->conn->privateData;
    char uuidstr[VIR_UUID_STRING_BUFLEN];

    vm = virDomainObjListFindByUUID(privconn->driver->domains, domain->uuid);
    if (!vm) {
        virUUIDFormat(domain->uuid, uuidstr);
        virReportError(VIR_ERR_NO_DOMAIN,
                       _("no domain with matching uuid '%s' (%s)"),
                       uuidstr, domain->name);
        return NULL;
    }

    return vm;
}
