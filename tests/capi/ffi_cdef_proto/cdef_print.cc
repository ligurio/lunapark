/*
 * SPDX-License-Identifier: ISC
 *
 * Copyright 2023-2026, Sergey Bronnikov
 */
#include "cdef_print.h"

#include <stack>
#include <string>

#define C99 1

/*
 * A declaration is a C language construct that introduces one
 * or more identifiers into the program and specifies their
 * meaning and properties.
 *
 * - https://en.cppreference.com/w/c/language/declarations
 * - https://luajit.org/ext_ffi_semantics.html
 * - src/lj_ctype.c
 * - https://learn.microsoft.com/en-us/cpp/c-language/summary-of-declarations
 */

/*
 * If control flow reaches the point of the unreachable(),
 * the program is undefined. It is useful in situations where
 * the compiler cannot deduce the unreachability of the code.
 */
#if __has_builtin(__builtin_unreachable) || defined(__GNUC__)
#  define unreachable() (assert(0), __builtin_unreachable())
#else
#  define unreachable() (assert(0))
#endif

using namespace cdef;

#define PROTO_TOSTRING(TYPE, VAR_NAME) \
	std::string TYPE##ToString(const TYPE & (VAR_NAME))

/* PROTO_TOSTRING version for nested (depth=2) protobuf messages. */
#define NESTED_PROTO_TOSTRING(TYPE, VAR_NAME, PARENT_MESSAGE) \
	std::string TYPE##ToString \
	(const PARENT_MESSAGE::TYPE & (VAR_NAME))

namespace ffi_cdef_proto {
namespace {

/*
 * This is a list of reserved keywords in C. Since they are used
 * by the language, these keywords are not available for
 * re-definition. As an exception, they are not considered
 * reserved in attribute-tokens (since C23).
 * See https://en.cppreference.com/w/c/keyword.
 */
const std::set<std::string> KReservedCKeywords {
	"alignas",
	"alignof",
	"auto",
	"bool",
	"break",
	"case",
	"char",
	"const",
	"constexpr",
	"continue",
	"default",
	"do",
	"double",
	"else",
	"enum",
	"extern",
	"false",
	"float",
	"for",
	"goto",
	"if",
	"inline",
	"int",
	"long",
	"nullptr",
	"register",
	"restrict",
	"return",
	"short",
	"signed",
	"sizeof",
	"static",
	"static_assert",
	"struct",
	"switch",
	"thread_local",
	"true",
	"typedef",
	"typeof",
	"typeof_unqual",
	"union",
	"unsigned",
	"void",
	"volatile",
	"while",
	"_Alignas",
	"_Alignof",
	"_Atomic",
	"_BitInt",
	"_Bool",
	"_Complex",
	"_Decimal128",
	"_Decimal32",
	"_Decimal64",
	"_Generic",
	"_Imaginary",
	"_Noreturn",
	"_Static_assert",
	"_Thread_local",
};

PROTO_TOSTRING(Identifier, identifier);

PROTO_TOSTRING(StaticAssertion, static_assertion);
PROTO_TOSTRING(StructDeclaration, struct_declaration);
PROTO_TOSTRING(StructDeclarationList, struct_declaration_list);

/* Type specifiers. */
PROTO_TOSTRING(ArithmeticType, arithmetic_type);
PROTO_TOSTRING(AtomicType, atomic_type);
PROTO_TOSTRING(TypedefType, typedef_type);
PROTO_TOSTRING(StructType, struct_type);
PROTO_TOSTRING(UnionType, union_type);
PROTO_TOSTRING(EnumType, enum_type);
PROTO_TOSTRING(TypeOfOperator, typeof_operator);
PROTO_TOSTRING(Bitfield, bit_field_type);

PROTO_TOSTRING(DeclaratorsAndInitializers, declarators_and_initializers);
PROTO_TOSTRING(Specifier, specifier);
PROTO_TOSTRING(Qualifier, qualifier);
PROTO_TOSTRING(QualifiersList, qualifiers_list);
PROTO_TOSTRING(SpecifiersList, specifiers_list);
PROTO_TOSTRING(SpecifierAndQualifier, specifier_and_qualifier);
PROTO_TOSTRING(SpecifiersAndQualifiersList, specifiers_and_qualifiers_list);

/* Specifiers and qualifiers. */
PROTO_TOSTRING(TypeSpecifier, type_specifier);
PROTO_TOSTRING(StorageClassSpecifier, storage_class_specifier);
PROTO_TOSTRING(FunctionSpecifier, function_specifier);
PROTO_TOSTRING(AlignmentSpecifier, alignment_specifier);
PROTO_TOSTRING(TypeQualifier, type_qualifier);

/* Declarators and initializers. */
PROTO_TOSTRING(Declarator, declarator);
PROTO_TOSTRING(Initializer, initializer);

/* Declarators. */
PROTO_TOSTRING(DeclaratorAttr, declarator_attr);
PROTO_TOSTRING(DeclaratorParentheses, declarator_parentheses);
PROTO_TOSTRING(FunctionDeclarator, function_declarator);
PROTO_TOSTRING(PointerDeclarator, pointer_declarator);
PROTO_TOSTRING(ArrayDeclarator, array_declarator);

PROTO_TOSTRING(Declaration, cdecl);
PROTO_TOSTRING(Declarations, cdef);

/*
 * Identifier,
 * https://en.cppreference.com/w/c/language/identifier
 * https://en.cppreference.com/w/cpp/language/identifiers
 */
std::string
ClearIdentifier(const std::string &identifier)
{
	/* FIXME */
	std::string cleared;

	bool has_first_not_digit = false;
	for (char c : identifier) {
		if (has_first_not_digit && (std::iswalnum(c) || c == '_')) {
			cleared += c;
		} else if (std::isalpha(c) || c == '_') {
			has_first_not_digit = true;
			cleared += c;
		}
	}
	return cleared;
}

inline std::string
clamp(std::string s, size_t maxSize = kMaxStrLength)
{
	if (s.size() > maxSize)
		s.resize(maxSize);
	return s;
}

inline std::string
ConvertToStringDefault(const std::string &s)
{
	std::string ident = ClearIdentifier(s);
	ident = clamp(ident);
	if (ident.empty())
		return std::string(kDefaultIdent);
	return ident;
}

/*
 * Identifier (Name).
 * https://en.cppreference.com/w/c/language/identifier
 * https://en.cppreference.com/w/cpp/language/identifiers
 */
PROTO_TOSTRING(Identifier, identifier)
{
	std::string identifier_str;
	identifier_str += ConvertToStringDefault(identifier.name());
	identifier_str += std::to_string(identifier.num() % kMaxIdentifiers);
	if (KReservedCKeywords.find(identifier_str) !=
		KReservedCKeywords.end()) {
		identifier_str += "_1";
	}

	return identifier_str;
}

PROTO_TOSTRING(IdentifiersList, identifiers)
{
	std::string identifiers_list_str;
	for (int i = 0; i < identifiers.identifiers_size(); ++i) {
		std::string ident_str = IdentifierToString(identifiers.identifiers(i));
		if (ident_str.empty())
			continue;
		if (i != 0)
			identifiers_list_str += ", ";
		identifiers_list_str += ident_str;
	}

	return identifiers_list_str;
}

PROTO_TOSTRING(Parameter, parameter)
{
	std::string parameter_str;
	parameter_str += IdentifierToString(parameter.name());
	return parameter_str;
}

PROTO_TOSTRING(Parameters, parameters)
{
	std::string parameters_str;
	for (int i = 0; i < parameters.parameters_size(); ++i) {
		parameters_str += ParameterToString(parameters.parameters(i));
		if (i != parameters.parameters_size() - 1)
			parameters_str += ", ";
	}
	return parameters_str;
}

PROTO_TOSTRING(ParametersList, parameters_list)
{
	std::string parameters_list_str;

	using ParametersList = ParametersList::ParametersListOneofCase;
	switch (parameters_list.parameters_list_oneof_case()) {
	case ParametersList::kKeywordVoid:
		parameters_list_str += "void";
		break;
	case ParametersList::kParameters:
		parameters_list_str +=
			ParametersToString(parameters_list.parameters());
		break;
	default:
		break;
	}

	if (parameters_list.has_ellipsis()) {
		if (!parameters_list_str.empty())
			parameters_list_str += ", ";
		parameters_list_str += "...";
	}

	return parameters_list_str;
}

PROTO_TOSTRING(TypeQualifier, type_qualifier)
{
	std::string type_qualifier_str;
	if (type_qualifier.has_keyword_const())
		type_qualifier_str += "const";
	if (type_qualifier.has_keyword_volatile()) {
		if (!type_qualifier_str.empty())
			type_qualifier_str += " ";
		type_qualifier_str += "volatile";
	}
	if (type_qualifier.has_keyword_restrict()) {
		if (!type_qualifier_str.empty())
			type_qualifier_str += " ";
		type_qualifier_str += "restrict";
	}
	if (type_qualifier.has_keyword_atomic()) {
		if (!type_qualifier_str.empty())
			type_qualifier_str += " ";
		type_qualifier_str += "atomic";
	}

	return type_qualifier_str;
}

PROTO_TOSTRING(AlignmentSpecifier, alignment_specifier)
{
	std::string alignment_specifier_str;
	if (alignment_specifier.has_alignment_specifier_alignas())
		alignment_specifier_str += "_Alignas";

	return alignment_specifier_str;
}

PROTO_TOSTRING(FunctionSpecifier, function_specifier)
{
	std::string function_specifier_str;
	if (function_specifier.has_keyword_inline()) {
		function_specifier_str += "inline";
	}

	if (function_specifier.has_keyword_noreturn()) {
		if (!function_specifier_str.empty())
			function_specifier_str += " ";
		function_specifier_str += "_Noreturn";
	}

	return function_specifier_str;
}

PROTO_TOSTRING(StorageClassSpecifier, storage_class_specifier)
{
	std::string storage_class_specifier_str;
	using StorageClassSpecifierKeyword = StorageClassSpecifier::StorageClassSpecifierOneofCase;
	switch (storage_class_specifier.storage_class_specifier_oneof_case()) {
	case StorageClassSpecifierKeyword::kStorageClassTypedef:
		storage_class_specifier_str = "typedef";
		break;
	case StorageClassSpecifierKeyword::kStorageClassConstexpr:
		storage_class_specifier_str = "constexpr";
		break;
	case StorageClassSpecifierKeyword::kStorageClassAuto:
		storage_class_specifier_str = "auto";
		break;
	case StorageClassSpecifierKeyword::kStorageClassRegister:
		storage_class_specifier_str = "register";
		break;
	case StorageClassSpecifierKeyword::kStorageClassStatic:
		storage_class_specifier_str = "static";
		break;
	case StorageClassSpecifierKeyword::kStorageClassExtern:
		storage_class_specifier_str = "extern";
		break;
	case StorageClassSpecifierKeyword::kStorageClassThreadLocal1:
		storage_class_specifier_str = "thread_local";
		break;
	case StorageClassSpecifierKeyword::kStorageClassThreadLocal2:
		storage_class_specifier_str = "_Thread_local";
		break;
	default:
		break;
	}

	return storage_class_specifier_str;
}

PROTO_TOSTRING(TypeSpecifier, type_specifier)
{
	std::string type_specifier_str;
	using TypeType = TypeSpecifier::TypeSpecifierOneofCase;
	switch (type_specifier.type_specifier_oneof_case()) {
	case TypeType::kVoidType:
		type_specifier_str = "void";
		break;
	case TypeType::kArithmeticType:
		type_specifier_str =
			ArithmeticTypeToString(type_specifier.arithmetic_type());
		break;
	case TypeType::kAtomicType:
		type_specifier_str =
			AtomicTypeToString(type_specifier.atomic_type());
		break;
	case TypeType::kTypedefType:
		type_specifier_str =
			TypedefTypeToString(type_specifier.typedef_type());
		break;
	case TypeType::kStructType:
		type_specifier_str =
			StructTypeToString(type_specifier.struct_type());
		break;
	case TypeType::kUnionType:
		type_specifier_str =
			UnionTypeToString(type_specifier.union_type());
		break;
	case TypeType::kEnumType:
		type_specifier_str =
			EnumTypeToString(type_specifier.enum_type());
		break;
	case TypeType::kTypeofOperator:
		type_specifier_str =
			TypeOfOperatorToString(type_specifier.typeof_operator());
		break;
	default:
		break;
	}

	return type_specifier_str;
}

PROTO_TOSTRING(Specifier, specifier)
{
	std::string specifier_str;
	using Spec = Specifier::SpecifierOneofCase;
	switch (specifier.specifier_oneof_case()) {
	case Spec::kTypeSpecifier:
		specifier_str +=
			TypeSpecifierToString(specifier.type_specifier());
		break;
	case Spec::kStorageClassSpecifier:
		specifier_str +=
			StorageClassSpecifierToString(specifier.storage_class_specifier());
		break;
	case Spec::kFunctionSpecifier:
		specifier_str +=
			FunctionSpecifierToString(specifier.function_specifier());
		break;
	case Spec::kAlignmentSpecifier:
		specifier_str +=
			AlignmentSpecifierToString(specifier.alignment_specifier());
		break;
	default:
		break;
	}

	return specifier_str;
}

PROTO_TOSTRING(SpecifiersList, specifiers_list)
{
	std::string specifiers_list_str;
	for (int i = 0; i < specifiers_list.specifiers_list_size(); ++i) {
		std::string spec_list = SpecifierToString(specifiers_list.specifiers_list(i));
		if (spec_list.empty())
			continue;
		if (i != 0)
			specifiers_list_str += " ";
		specifiers_list_str += spec_list;
	}

	return specifiers_list_str;
}

PROTO_TOSTRING(Qualifier, qualifier)
{
	std::string qualifier_str;
	using Qual = Qualifier::QualifierOneofCase;
	switch (qualifier.qualifier_oneof_case()) {
	case Qual::kTypeQualifier:
		qualifier_str +=
			TypeQualifierToString(qualifier.type_qualifier());
		break;
	default:
		break;
	}

	return qualifier_str;
}

PROTO_TOSTRING(QualifiersList, qualifiers_list)
{
	std::string qualifiers_list_str;
	for (int i = 0; i < qualifiers_list.qualifiers_list_size(); ++i) {
		std::string qualifier_str = QualifierToString(qualifiers_list.qualifiers_list(i));
		if (qualifier_str.empty())
			continue;
		if (!qualifiers_list_str.empty())
			qualifiers_list_str += " ";
		qualifiers_list_str += QualifierToString(qualifiers_list.qualifiers_list(i));
	}

	return qualifiers_list_str;
}

PROTO_TOSTRING(SpecifierAndQualifier, specifier_and_qualifier)
{
	std::string specifier_and_qualifier_str;
	if (specifier_and_qualifier.has_specifiers_list()) {
		if (!specifier_and_qualifier_str.empty())
			specifier_and_qualifier_str += " ";
		specifier_and_qualifier_str +=
			SpecifiersListToString(specifier_and_qualifier.specifiers_list());
	}
	if (specifier_and_qualifier.has_qualifiers_list()) {
		if (!specifier_and_qualifier_str.empty())
			specifier_and_qualifier_str += " ";
		specifier_and_qualifier_str +=
			QualifiersListToString(specifier_and_qualifier.qualifiers_list());
	}

	return specifier_and_qualifier_str;
}

PROTO_TOSTRING(SpecifiersAndQualifiersList, specifiers_and_qualifiers_list)
{
	std::string specifiers_and_qualifiers_list_str;
	for (int i = 0; i < specifiers_and_qualifiers_list.specifiers_and_qualifiers_list_size(); ++i) {
		specifiers_and_qualifiers_list_str +=
			SpecifierAndQualifierToString(specifiers_and_qualifiers_list.specifiers_and_qualifiers_list(i));
		if (!specifiers_and_qualifiers_list_str.empty() &&
			i != specifiers_and_qualifiers_list.specifiers_and_qualifiers_list_size() - 1)
			specifiers_and_qualifiers_list_str += " ";
	}

	return specifiers_and_qualifiers_list_str;
}

PROTO_TOSTRING(Declarator, declarator)
{
	std::string declarator_str;
	using TDeclarator = Declarator::DeclaratorOneofCase;
	switch (declarator.declarator_oneof_case()) {
	case TDeclarator::kDeclaratorAttr:
		declarator_str +=
			DeclaratorAttrToString(declarator.declarator_attr());
		break;
	case TDeclarator::kDeclaratorParentheses:
		declarator_str +=
			DeclaratorParenthesesToString(declarator.declarator_parentheses());
		break;
	case TDeclarator::kPointerDeclarator:
		declarator_str +=
			PointerDeclaratorToString(declarator.pointer_declarator());
		break;
	case TDeclarator::kArrayDeclarator:
		declarator_str +=
			ArrayDeclaratorToString(declarator.array_declarator());
		break;
	case TDeclarator::kFunctionDeclarator:
		declarator_str +=
			FunctionDeclaratorToString(declarator.function_declarator());
		break;
	default:
		break;
	}

	return declarator_str;
}

/*
 * Initialization.
 */
PROTO_TOSTRING(Initializer, initializer)
{
	/* FIXME: Not implemented. */
	return "";
}

PROTO_TOSTRING(DeclaratorsAndInitializers, declarators_and_initializers)
{
	std::string declarators_and_initializers_str;
	for (int i = 0; i < declarators_and_initializers.declarators_size(); ++i) {
		declarators_and_initializers_str +=
			DeclaratorToString(declarators_and_initializers.declarators(i));
		if (i != declarators_and_initializers.declarators_size() - 1)
			declarators_and_initializers_str += ", ";
	}

	for (int i = 0; i < declarators_and_initializers.initializers_size(); ++i) {
		declarators_and_initializers_str +=
			InitializerToString(declarators_and_initializers.initializers(i));
	}

	return declarators_and_initializers_str;
}

PROTO_TOSTRING(AttrSpecSeq, attr_spec_seq)
{
	std::string attr_spec_seq_str;
#ifdef C99
	return attr_spec_seq_str;
#endif /* C99 */
	if (attr_spec_seq.has_keyword_deprecated()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[deprecated]]";
	}

	if (attr_spec_seq.has_keyword_deprecated_reason()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[deprecated(\"reason\")]]";
	}

	if (attr_spec_seq.has_keyword_fallthrough()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[fallthrough]]";
	}

	if (attr_spec_seq.has_keyword_nodiscard()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[nodiscard]]";
	}

	if (attr_spec_seq.has_keyword_nodiscard_reason()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[nodiscard(\"reason\")]]";
	}

	if (attr_spec_seq.has_keyword_maybe_unused()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[maybe_unused]]";
	}

	if (attr_spec_seq.has_keyword_noreturn_1()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[noreturn]]";
	}

	if (attr_spec_seq.has_keyword_noreturn_2()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[_Noreturn]]";
	}

	if (attr_spec_seq.has_keyword_unsequenced()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[unsequenced]]";
	}

	if (attr_spec_seq.has_keyword_reproducible()) {
		if (!attr_spec_seq_str.empty())
			attr_spec_seq_str += " ";
		attr_spec_seq_str += "[[reproducible]]";
	}

	return attr_spec_seq_str;
}

PROTO_TOSTRING(DeclaratorAttr, declarator_attr)
{
	std::string declarator_attr_str;
	declarator_attr_str += IdentifierToString(declarator_attr.name());
	if (declarator_attr.has_attr_spec_seq())
		declarator_attr_str += " " +
			AttrSpecSeqToString(declarator_attr.attr_spec_seq());

	return declarator_attr_str;
}

PROTO_TOSTRING(DeclaratorParentheses, declarator_parentheses)
{
	std::string declarator_parentheses_str = "(";
	declarator_parentheses_str +=
		DeclaratorToString(declarator_parentheses.declarator());
	declarator_parentheses_str += ")";

	return declarator_parentheses_str;
}

/*
 * Function declaration.
 */
PROTO_TOSTRING(FunctionDeclarator, function_declarator)
{
	std::string function_declarator_str;
	function_declarator_str +=
		DeclaratorToString(function_declarator.noptr_declarator());
	function_declarator_str += "(";

	using FuncDecl = FunctionDeclarator::ParenthesesContentOneofCase;
	switch (function_declarator.parentheses_content_oneof_case()) {
	case FuncDecl::kParametersList:
		function_declarator_str +=
			ParametersListToString(function_declarator.parameters_list());
		break;
	case FuncDecl::kIdentifiersList:
		function_declarator_str +=
			IdentifiersListToString(function_declarator.identifiers_list());
		break;
	default:
		break;
	}

	function_declarator_str += ")";

	if (function_declarator.has_attr_spec_seq())
		function_declarator_str += " " +
			AttrSpecSeqToString(function_declarator.attr_spec_seq());

	return function_declarator_str;
}

/*
 * Pointer declaration.
 */
PROTO_TOSTRING(PointerDeclarator, pointer_declarator)
{
	std::string pointer_declarator_str = "*";
	if (pointer_declarator.has_attr_spec_seq())
		pointer_declarator_str += " " +
			AttrSpecSeqToString(pointer_declarator.attr_spec_seq());
	if (pointer_declarator.has_qualifiers_list())
		pointer_declarator_str += " " +
			QualifiersListToString(pointer_declarator.qualifiers_list());
	pointer_declarator_str += DeclaratorToString(pointer_declarator.declarator());

	return pointer_declarator_str;
}

/*
 * Array declaration.
 */
PROTO_TOSTRING(ArrayDeclarator, array_declarator)
{
	std::string array_declarator_str;
	if (array_declarator.has_keyword_static() &&
	    array_declarator.has_qualifiers_list() &&
		array_declarator.has_expression()) {
		array_declarator_str += "static ";
		array_declarator_str += QualifiersListToString(array_declarator.qualifiers_list());
		/* FIXME: expression is not a constant number. */
		array_declarator_str +=
			"[" +
			std::to_string(array_declarator.expression()) +
			"]";
	} else if (array_declarator.has_qualifiers_list()) {
		array_declarator_str +=
			"[" +
			QualifiersListToString(array_declarator.qualifiers_list()) +
			" * ]";
	} else
		return "";

	if (array_declarator.has_attr_spec_seq())
		array_declarator_str += " " +
			AttrSpecSeqToString(array_declarator.attr_spec_seq());

	return array_declarator_str;
}

/*
 * Bitfield.
 */
PROTO_TOSTRING(Bitfield, bit_field_type)
{
	std::string bit_field_type_str;
	if (bit_field_type.has_name())
		bit_field_type_str += IdentifierToString(bit_field_type.name());
	bit_field_type_str += " : " + std::to_string(bit_field_type.width());

	return bit_field_type_str;
}

/*
 * Arithmetic types.
 */
PROTO_TOSTRING(ArithmeticType, arithmetic_type)
{
	std::string type_str;
	using TypeType = ArithmeticType::ArithmeticOneofCase;
	switch (arithmetic_type.arithmetic_oneof_case()) {
	/* Boolean type. */
	case TypeType::kTypeBool1:
		type_str = "bool";
		break;
	case TypeType::kTypeBool2:
		type_str = "_Bool";
		break;
	/* Character types. */
	case TypeType::kTypeSignedChar:
		type_str = "signed char";
		break;
	case TypeType::kTypeUnsignedChar:
		type_str = "unsigned char";
		break;
	case TypeType::kTypeChar:
		type_str = "char";
		break;
	/* Integer types. */
	case TypeType::kTypeShortInt1:
		type_str = "short int";
		break;
	case TypeType::kTypeShortInt2:
		type_str = "short";
		break;
	case TypeType::kTypeShortInt3:
		type_str = "signed";
		break;
	case TypeType::kTypeUnsignedShortInt1:
		type_str = "unsigned short int";
		break;
	case TypeType::kTypeUnsignedShortInt2:
		type_str = "unsigned short";
		break;
	case TypeType::kTypeInt1:
		type_str = "int";
		break;
	case TypeType::kTypeInt2:
		type_str = "signed int";
		break;
	case TypeType::kTypeUnsignedInt1:
		type_str = "unsigned int";
		break;
	case TypeType::kTypeUnsignedInt2:
		type_str = "unsigned";
		break;
	case TypeType::kTypeLongInt1:
		type_str = "long int";
		break;
	case TypeType::kTypeLongInt2:
		type_str = "long";
		break;
	case TypeType::kTypeUnsignedLongInt1:
		type_str = "unsigned long int";
		break;
	case TypeType::kTypeUnsignedLongInt2:
		type_str = "unsigned long";
		break;
	case TypeType::kTypeLongLongInt1:
		type_str = "long long int";
		break;
	case TypeType::kTypeLongLongInt2:
		type_str = "long long";
		break;
	case TypeType::kTypeUnsignedLongLongInt1:
		type_str = "unsigned long long int";
		break;
	case TypeType::kTypeUnsignedLongLongInt2:
		type_str = "unsigned long long";
		break;
	case TypeType::kTypeBitInt:
		/* XXX: Fixed precise width. */
		type_str = "_BitInt(1)";
		break;
	case TypeType::kTypeUnsignedBitInt:
		/* XXX: Fixed precise width. */
		type_str = "unsigned _BitInt(1)";
		break;
	/* Real floating types. */
	case TypeType::kTypeFloat:
		type_str = "float";
		break;
	case TypeType::kTypeDouble:
		type_str = "double";
		break;
	case TypeType::kTypeLongDouble:
		type_str = "long double";
		break;
	case TypeType::kTypeDecimal32:
		type_str = "_Decimal32";
		break;
	case TypeType::kTypeDecimal64:
		type_str = "_Decimal64";
		break;
	case TypeType::kTypeDecimal128:
		type_str = "_Decimal128";
		break;
	/* Complex floating types. */
	case TypeType::kTypeFloatComplex:
		type_str = "float complex";
		break;
	case TypeType::kTypeDoubleComplex:
		type_str = "double complex";
		break;
	case TypeType::kTypeLongDoubleComplex:
		type_str = "long double complex";
		break;
	/* Imaginary floating types. */
	case TypeType::kTypeFloatImaginary:
		type_str = "float imaginary";
		break;
	case TypeType::kTypeDoubleImaginary:
		type_str = "double imaginary";
		break;
	case TypeType::kTypeLongDoubleImaginary:
		type_str = "long double imaginary";
		break;
	default:
		break;
	}

	return type_str;
}

/*
 * Atomic types.
 */
PROTO_TOSTRING(AtomicType, atomic_type)
{
	return "_Atomic";
}

/*
 * Typedef declaration.
 */
PROTO_TOSTRING(TypedefType, typedef_type)
{
	/* FIXME: Not implemented. */
	return "";
}

/*
 * Static assertion.
 */
PROTO_TOSTRING(StaticAssertion, static_assertion)
{
	std::string static_assertion_str;
	using StaticAssert = StaticAssertion::StaticAssertOneofCase;
	switch (static_assertion.static_assert_oneof_case()) {
	case StaticAssert::kStaticAssert1:
		static_assertion_str += "_Static_assert";
		break;
	case StaticAssert::kStaticAssert2:
		static_assertion_str += "static_assert";
		break;
	default:
		break;
	}

	if (static_assertion_str.empty())
		return static_assertion_str;

	static_assertion_str += "(";
	static_assertion_str += std::to_string(static_assertion.expression());
	static_assertion_str += ")";

	if (static_assertion.has_message())
		static_assertion_str += ", " + static_assertion.message();

	if (!static_assertion_str.empty())
		static_assertion_str += ";\n";

	return static_assertion_str;
}

PROTO_TOSTRING(StructDeclaration, struct_declaration)
{
	std::string struct_declaration_str;
	using StructDecl = StructDeclaration::StructDeclOneofCase;
	switch (struct_declaration.struct_decl_oneof_case()) {
	case StructDecl::kBitField:
		struct_declaration_str +=
			"  " + BitfieldToString(struct_declaration.bit_field());
		break;
	case StructDecl::kStaticAssertion:
		struct_declaration_str +=
			"  " + StaticAssertionToString(struct_declaration.static_assertion());
		break;
	default:
		break;
	}

	return struct_declaration_str;
}

PROTO_TOSTRING(StructDeclarationList, struct_declaration_list)
{
	std::string struct_declaration_list_str;
	struct_declaration_list_str += "\n";
	for (int i = 0; i < struct_declaration_list.struct_declaration_list_size(); ++i) {
		std::string struct_declaration_str =
			StructDeclarationToString(struct_declaration_list.struct_declaration_list(i));
		if (struct_declaration_str.empty())
			continue;
		struct_declaration_list_str += struct_declaration_str + ";\n";
	}

	return struct_declaration_list_str;
}

/*
 * Struct declaration.
 */
PROTO_TOSTRING(StructType, struct_type)
{
	std::string struct_type_str = "struct";

	if (struct_type.has_attr_spec_seq())
		struct_type_str += " " +
			AttrSpecSeqToString(struct_type.attr_spec_seq());
	if (struct_type.has_name()) {
		if (!struct_type_str.empty())
			struct_type_str += " ";
		struct_type_str += IdentifierToString(struct_type.name());
	}

	struct_type_str += "\n{";
	struct_type_str +=
		StructDeclarationListToString(struct_type.struct_declaration_list());
	struct_type_str += "\n};\n";

	return struct_type_str;
}

/*
 * Union.
 */
PROTO_TOSTRING(UnionType, union_type)
{
	std::string union_type_str = "union";

	if (union_type.has_attr_spec_seq())
		union_type_str += " " + AttrSpecSeqToString(union_type.attr_spec_seq());

	if (union_type.has_name())
		union_type_str += " " + IdentifierToString(union_type.name());

	union_type_str += "\n{";
	union_type_str +=
		StructDeclarationListToString(union_type.struct_declaration_list());
	union_type_str += "\n};\n";

	return union_type_str;
}

/*
 * Enumerations.
 */
PROTO_TOSTRING(EnumType, enum_type)
{
	std::string enum_type_str;
	enum_type_str += "enum ";
	enum_type_str += IdentifierToString(enum_type.enum_name());
	enum_type_str += " {";
	for (int i = 0; i < enum_type.constant_size(); ++i) {
		enum_type_str += IdentifierToString(enum_type.constant(i));
		if (i != enum_type.constant_size() - 1 &&
			!enum_type_str.empty())
			enum_type_str += ", ";
	}
	enum_type_str += "};\n";

	return enum_type_str;
}

/*
 * typeof operators (since C23).
 */
PROTO_TOSTRING(TypeOfOperator, typeof_operator)
{
	/* FIXME: Not implemented. */
	return "";
}

/*
 * Single declaration.
 */
PROTO_TOSTRING(Declaration, declaration)
{
	std::string declaration_str;
	std::string specifiers_and_qualifiers_list_str =
		SpecifiersAndQualifiersListToString(declaration.specifiers_and_qualifiers_list());
	std::string declarators_and_initializers_str =
		DeclaratorsAndInitializersToString(declaration.declarators_and_initializers());
	if (declaration.has_attr_spec_seq()) {
		declaration_str += AttrSpecSeqToString(declaration.attr_spec_seq());
		if (declaration.has_declarators_and_initializers() &&
			declaration.has_specifiers_and_qualifiers_list()) {
			declaration_str += specifiers_and_qualifiers_list_str;
			declaration_str += " ";
			declaration_str += declarators_and_initializers_str;
		}
		if (!declaration_str.empty())
			declaration_str += ";\n";

		return declaration_str;
	}

	if (declaration.has_specifiers_and_qualifiers_list()) {
		declaration_str += specifiers_and_qualifiers_list_str;
		if (declaration.has_declarators_and_initializers() &&
			!declarators_and_initializers_str.empty())
			declaration_str += " " + declarators_and_initializers_str;
		if (!declaration_str.empty())
			declaration_str += ";\n";

		return declaration_str;
	}

	return declaration_str;
}

/*
 * Declarations.
 */
PROTO_TOSTRING(Declarations, declarations)
{
	std::string declarations_str;

	for (int i = 0; i < declarations.declarations_size(); ++i)
		declarations_str += DeclarationToString(declarations.declarations(i));

	return declarations_str;
}

} /* namespace */

std::string
MainDefinitionsToString(const Declarations &decls)
{
	std::string decls_str = DeclarationsToString(decls);

	return decls_str;
}

} /* namespace ffi_cdef_proto */
