import { z } from "zod";
import { ORG_ROLES } from "./permissions";

/** Canonical money is a decimal string; zod validates shape, helpers normalize. */
export const MoneyString = z
  .string()
  .regex(/^-?\d+(\.\d{1,2})?$/, "invalid_amount");

export const NonNegativeMoney = MoneyString.regex(/^\d+(\.\d{1,2})?$/, "invalid_amount");

export const SemVer = z.string().regex(/^\d+\.\d+\.\d+$/, "invalid_version");

export const UUID = z.string().uuid();

export const Phone = z
  .string()
  .regex(/^\+?[0-9\s-]{7,20}$/, "invalid_phone")
  .optional();

export const Email = z.string().email("invalid_email");

/** Ethiopian phone numbers: accept local 09... or international +2519... */
export const EthiopianPhone = z
  .string()
  .regex(/^(\+251|0)(9|7)\d{8}$/, "invalid_phone");

export const OrgRoleSchema = z.enum(ORG_ROLES);

export const PropertyTypeSchema = z.enum(["residential", "commercial", "mixed_use"]);
export const UnitKindSchema = z.enum(["shop", "apartment", "office", "storage"]);
export const UnitStatusSchema = z.enum(["vacant", "rented", "maintenance"]);
export const LeaseStatusSchema = z.enum(["draft", "active", "ended", "terminated"]);
export const ChargeStatusSchema = z.enum(["pending", "partial", "paid", "overdue", "void"]);
export const PaymentMethodSchema = z.enum([
  "cash",
  "bank_transfer",
  "telebirr",
  "chapa",
  "cheque",
  "other",
]);
export const StockMovementTypeSchema = z.enum(["in", "out", "adjustment", "rental_out", "rental_return"]);
export const NotificationChannelSchema = z.enum(["push", "sms", "email", "in_app"]);

export const LocaleSchema = z.enum(["en", "am", "om"]);

// ---- Auth ----
export const LoginSchema = z.object({
  identifier: z.string().min(3, "required"), // email or phone
  password: z.string().min(8, "password_too_short"),
  remember: z.boolean().optional().default(true),
});
export type LoginInput = z.infer<typeof LoginSchema>;

/**
 * Sign-up collects a display name ("username"), the phone number and a
 * password. The phone is the sign-in identifier (GoTrue `phone` + password);
 * there is no email field. `fullName` is stored on `profiles.full_name` via
 * `handle_new_user()`.
 */
export const SignUpSchema = z.object({
  fullName: z.string().min(2, "required"),
  phone: EthiopianPhone,
  password: z
    .string()
    .min(8, "password_too_short")
    .regex(/[A-Z]/, "password_needs_upper")
    .regex(/[0-9]/, "password_needs_digit"),
});
export type SignUpInput = z.infer<typeof SignUpSchema>;

// ---- Property / unit ----
export const CreatePropertySchema = z.object({
  name: z.string().min(1, "required"),
  type: PropertyTypeSchema,
  addressLine: z.string().optional(),
  subCity: z.string().optional(),
  city: z.string().optional(),
  latitude: z.number().min(-90).max(90).nullable().optional(),
  longitude: z.number().min(-180).max(180).nullable().optional(),
  floors: z.number().int().positive().nullable().optional(),
  unitsCount: z.number().int().positive().optional(),
  averageRent: NonNegativeMoney.optional(),
  notes: z.string().optional(),
});
export type CreatePropertyInput = z.infer<typeof CreatePropertySchema>;

export const CreateUnitSchema = z.object({
  propertyId: UUID,
  code: z.string().min(1, "required"),
  kind: UnitKindSchema.default("shop"),
  floorLabel: z.string().optional(),
  areaSqM: z.number().positive().nullable().optional(),
  monthlyRent: NonNegativeMoney.default("0"),
  hasSeparateMeter: z.boolean().default(false),
  hasStorage: z.boolean().default(false),
});
export type CreateUnitInput = z.infer<typeof CreateUnitSchema>;

// ---- Tenant / lease ----
export const CreateTenantSchema = z.object({
  fullName: z.string().min(2, "required"),
  businessName: z.string().optional(),
  phone: EthiopianPhone.optional(),
  email: Email.optional(),
});
export type CreateTenantInput = z.infer<typeof CreateTenantSchema>;

export const CreateTenantWithLeaseSchema = z.object({
  orgId: UUID,
  unitId: UUID,
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "invalid_date"),
  endDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, "invalid_date")
    .nullable()
    .optional(),
  monthlyRent: NonNegativeMoney,
  depositAmount: NonNegativeMoney.default("0"),
  billingDay: z.number().int().min(1).max(28).default(1),
  graceDays: z.number().int().min(0).max(60).default(5),
  tenant: CreateTenantSchema,
});
export type CreateTenantWithLeaseInput = z.infer<typeof CreateTenantWithLeaseSchema>;

/** Assign an existing tenant to a vacant unit (creates the active lease). */
export const AssignTenantToUnitSchema = z.object({
  unitId: UUID,
  tenantId: UUID,
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "invalid_date"),
  endDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, "invalid_date")
    .nullable()
    .optional(),
  monthlyRent: NonNegativeMoney,
  depositAmount: NonNegativeMoney.default("0"),
  billingDay: z.number().int().min(1).max(28).default(1),
  graceDays: z.number().int().min(0).max(60).default(5),
});
export type AssignTenantToUnitInput = z.infer<typeof AssignTenantToUnitSchema>;

// ---- Payment ----
export const RecordPaymentSchema = z.object({
  leaseId: UUID,
  amount: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, "invalid_amount")
    .refine((v) => Number(v) > 0, "invalid_amount"),
  method: PaymentMethodSchema,
  reference: z.string().optional(),
  paidAt: z.string().datetime().optional(),
  notes: z.string().optional(),
  idempotencyKey: z.string().min(8).optional(),
});
export type RecordPaymentInput = z.infer<typeof RecordPaymentSchema>;

// ---- Stock ----
export const StockAdjustSchema = z.object({
  itemId: UUID,
  type: z.enum(["in", "out", "adjustment"]),
  qty: z.string().regex(/^\d+(\.\d{1,3})?$/, "invalid_qty"),
  reason: z.string().optional(),
  unitId: UUID.nullable().optional(),
});
export type StockAdjustInput = z.infer<typeof StockAdjustSchema>;

export const CreateStockItemSchema = z.object({
  name: z.string().min(1, "required"),
  sku: z.string().optional(),
  category: z.string().optional(),
  uom: z.string().default("pcs"),
  quantity: z.string().regex(/^\d+(\.\d{1,3})?$/, "invalid_qty").default("0"),
  minQuantity: z.string().regex(/^\d+(\.\d{1,3})?$/, "invalid_qty").default("0"),
  isRentable: z.boolean().default(false),
  rentalRate: NonNegativeMoney.nullable().optional(),
  barcode: z.string().optional(),
  propertyId: UUID.nullable().optional(),
});
export type CreateStockItemInput = z.infer<typeof CreateStockItemSchema>;
