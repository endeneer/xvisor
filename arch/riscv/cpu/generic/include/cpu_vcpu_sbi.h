/**
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * @file cpu_vcpu_sbi.h
 * @author Atish Patra (atish.patra@wdc.com)
 * @brief header file for SBI call handling
 */
#ifndef _CPU_VCPU_SBI_H__
#define _CPU_VCPU_SBI_H__

#include <vmm_types.h>
#include <vmm_manager.h>

#define SBI_VERSION_MAJOR			0
#define SBI_VERSION_MINOR			1

int cpu_vcpu_sbi_ecall(struct vmm_vcpu *vcpu, ulong mcause,
		       arch_regs_t *regs);

#endif
