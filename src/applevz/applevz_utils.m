/*
 * applevz_utils.m: core driver functions for managing
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

#include <config.h>

#include "viralloc.h"

#include "applevz_utils.h"

void*
applevzDomObjAlloc(void *opaque G_GNUC_UNUSED)
{
    applevzDomObjPtr pdom = NULL;

    if (VIR_ALLOC(pdom) < 0)
        return NULL;

    /*
    if (virCondInit(&pdom->job.cond) < 0)
        goto error;

    pdom->stats = PRL_INVALID_HANDLE;

    */
    return pdom;

    /*
 error:
    VIR_FREE(pdom);

    return NULL;
    */
}

void
applevzDomObjFree(void* p)
{
    applevzDomObjPtr pdom = p;

    if (!pdom)
        return;

    /*
    PrlHandle_Free(pdom->sdkdom);
    PrlHandle_Free(pdom->stats);
    virCondDestroy(&pdom->job.cond);
    */
    VIR_FREE(pdom);
};
