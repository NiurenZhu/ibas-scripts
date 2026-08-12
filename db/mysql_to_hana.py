#!/usr/bin/env python3
"""Convert a MySQL dump produced by mysqldump into HANA SQL.

The converter handles the dump features used by the IBAS console backup:
CREATE/DROP TABLE, indexes, INSERT statements, and stored routines
(CREATE/DROP PROCEDURE and FUNCTION).  MySQL-specific syntax such as
DELIMITER directives, DEFINER clauses, and backtick quoting is converted
or stripped.  Identifiers are kept double-quoted so that the original
mixed-case column names and reserved words remain usable in HANA.  Table
names are uppercased by default; use --keep-table-case to retain their
original case.  The type choices follow the IBAS dm_hana_ibas_classic.xml
mapping.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


LOG_TABLE_PATTERNS = (
    re.compile(r"(?:^|_)SYS_BOLOGST$", re.I),
    re.compile(r"(?:^|_)SYS_USERACTLOG$", re.I),
)

DROP_OBJECT_PATTERN = re.compile(
    r"^DROP\s+(TABLE|VIEW|PROCEDURE|FUNCTION|TRIGGER|SEQUENCE|TYPE)\s+"
    r"(?:IF\s+EXISTS\s+)?(.+?)\s*$",
    re.I | re.S,
)

CREATE_TABLE_NAME_PATTERN = re.compile(
    r'^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"([^"]+)"',
    re.I,
)

# MySQL DEFINER clause: DEFINER=user@host (quoted or unquoted) or DEFINER=CURRENT_USER
DEFINER_PATTERN = re.compile(
    r"\s*DEFINER\s*=\s*"
    r"(?:CURRENT_USER(?:\(\))?"
    r"|"
    r"(?:`[^`]*`|\"[^\"]*\"|'[^']*'|[\w.]+)"
    r"\s*@\s*"
    r"(?:`[^`]*`|\"[^\"]*\"|'[^']*'|[%\w.]+))",
    re.I,
)

# MySQL DELIMITER directive (line-oriented)
DELIMITER_PATTERN = re.compile(r"^\s*DELIMITER\s+(\S+)\s*$", re.I)


MYSQL_TYPES = (
    (r"\bmediumint(?:\s*\(\s*\d+\s*\))?(?=\s|,|\)|$)", "INTEGER"),
    (r"\btinyint(?:\s*\(\s*\d+\s*\))?(?=\s|,|\)|$)", "INTEGER"),
    (r"\bsmallint\s*\(\s*\d+\s*\)(?=\s|,|\)|$)", "SMALLINT"),
    (r"\bint\s*\(\s*\d+\s*\)(?=\s|,|\)|$)", "INTEGER"),
    (r"\bbigint\s*\(\s*\d+\s*\)(?=\s|,|\)|$)", "BIGINT"),
    (r"\bdouble\b", "DOUBLE"),
    (r"\bfloat\b", "REAL"),
    (r"\bdatetime\b", "DATE"),
    (r"\btimestamp\b", "DATE"),
    (r"\bdecimal\s*\([^)]*\)", "NUMERIC(19, 6)"),
    (r"\bvarchar\s*\(\s*(\d+)\s*\)", r"NVARCHAR(\1)"),
    (r"\bchar\s*\(\s*(\d+)\s*\)", r"NVARCHAR(\1)"),
    (r"\b(?:tiny|medium|long)text\b", "NCLOB"),
    (r"\btext\b", "NCLOB"),
    (r"\b(?:tiny|medium|long)blob\b", "BLOB"),
)


def strip_dump_comments(source: str) -> str:
    """Remove mysqldump comments and MySQL conditional SET statements."""
    lines = []
    for line in source.splitlines(keepends=True):
        stripped = line.lstrip()
        if stripped.startswith("--") or stripped.startswith("#"):
            continue
        if stripped.startswith("/*!"):
            continue
        lines.append(line)
    return "".join(lines)


def _split_by_delimiter(source: str, delimiter: str) -> list[str]:
    """Split *source* on *delimiter* outside single-quoted string literals."""
    statements: list[str] = []
    start = 0
    in_string = False
    escaped = False
    index = 0
    delim_len = len(delimiter)
    while index < len(source):
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
            index += 1
        elif char == "'":
            in_string = True
            index += 1
        elif source[index : index + delim_len] == delimiter:
            statement = source[start:index].strip()
            if statement:
                statements.append(statement)
            start = index + delim_len
            index += delim_len
        else:
            index += 1
    tail = source[start:].strip()
    if tail:
        statements.append(tail)
    return statements


def split_statements(source: str) -> list[str]:
    """Split SQL on the active delimiter outside single-quoted string literals.

    MySQL dumps use ``DELIMITER`` directives to change the statement separator
    when defining stored routines whose bodies contain semicolons.  The
    directives themselves are consumed and do not appear in the output.
    """
    statements: list[str] = []
    delimiter = ";"
    buffer: list[str] = []

    for line in source.splitlines(keepends=True):
        match = DELIMITER_PATTERN.match(line)
        if match:
            text = "".join(buffer)
            if text.strip():
                statements.extend(_split_by_delimiter(text, delimiter))
            buffer = []
            delimiter = match.group(1)
            continue
        buffer.append(line)

    text = "".join(buffer)
    if text.strip():
        statements.extend(_split_by_delimiter(text, delimiter))

    return statements


def mysql_string_to_hana(value: str) -> str:
    """Convert the contents of a MySQL quoted string to SQL-standard quoting."""
    output: list[str] = []
    index = 0
    escapes = {
        "0": "\x00",
        "b": "\b",
        "t": "\t",
        "n": "\n",
        "r": "\r",
        "Z": "\x1a",
        "\\": "\\",
        "'": "'",
        '"': '"',
    }
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value):
            output.append(escapes.get(value[index + 1], value[index + 1]))
            index += 2
        else:
            output.append(char)
            index += 1
    return "".join(output).replace("'", "''")


def convert_string_literals(statement: str) -> str:
    result: list[str] = []
    index = 0
    while index < len(statement):
        if statement[index] != "'":
            result.append(statement[index])
            index += 1
            continue
        index += 1
        value: list[str] = []
        while index < len(statement):
            if statement[index] == "\\" and index + 1 < len(statement):
                value.extend((statement[index], statement[index + 1]))
                index += 2
            elif statement[index] == "'":
                index += 1
                break
            else:
                value.append(statement[index])
                index += 1
        result.append("'" + mysql_string_to_hana("".join(value)) + "'")
    return "".join(result)


def uppercase_table_name(statement: str) -> str:
    """Uppercase the quoted table name in CREATE TABLE or INSERT INTO."""
    pattern = re.compile(
        r'^(\s*(?:CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?|INSERT\s+INTO)\s+)"([^"]+)"',
        re.I,
    )
    return pattern.sub(lambda match: match.group(1) + '"' + match.group(2).upper() + '"', statement, count=1)


def convert_drop_statement(statement: str, uppercase_tables: bool = True) -> str | None:
    """Convert a MySQL DROP statement to HANA syntax."""
    match = DROP_OBJECT_PATTERN.match(statement.strip())
    if not match:
        return None
    object_type, names = match.groups()
    converted_names: list[str] = []
    for name in names.split(","):
        name = name.strip().strip("`").strip('"')
        if not name:
            continue
        if uppercase_tables:
            name = name.upper()
        converted_names.append(f'"{name}"')
    return "\n".join(f"DROP {object_type.upper()} {name};" for name in converted_names) or None


def _convert_routine(statement: str) -> str:
    """Convert MySQL CREATE PROCEDURE/FUNCTION to HANA syntax.

    * Strips MySQL-specific routine characteristics not supported by HANA.
    * Converts MySQL data types in the header to HANA equivalents.
    * Inserts ``AS`` before ``BEGIN`` (required by HANA SQLScript).
    """
    begin_match = re.search(r"(?m)^\s*BEGIN\b", statement)
    if begin_match:
        split_pos = begin_match.start()
        header = statement[:split_pos]
        body = statement[split_pos:]
        # Strip MySQL-specific routine characteristics not supported by HANA
        header = re.sub(r"\s+COMMENT\s+'(?:''|[^'])*'", "", header, flags=re.I)
        header = re.sub(r"\s+LANGUAGE\s+SQL\b", "", header, flags=re.I)
        header = re.sub(r"\s+CONTAINS\s+SQL\b", "", header, flags=re.I)
        header = re.sub(r"\s+NO\s+SQL\b", "", header, flags=re.I)
        header = re.sub(r"\s+MODIFIES\s+SQL\s+DATA\b", "", header, flags=re.I)
        # Convert MySQL data types in parameters and RETURNS clause
        for pattern, replacement in MYSQL_TYPES:
            header = re.sub(pattern, replacement, header, flags=re.I)
        # HANA requires AS before BEGIN in procedure/function bodies
        if not re.search(r"\bAS\s*$", header, re.I):
            header = header.rstrip() + "\nAS\n"
        statement = header + body
    return statement


def convert_statement(statement: str, uppercase_tables: bool = True) -> str | None:
    statement = statement.strip()
    if not statement:
        return None
    if re.match(r"^(LOCK TABLES|UNLOCK TABLES|USE)\b", statement, re.I):
        return None
    if re.match(r"^ALTER TABLE .* (DISABLE|ENABLE) KEYS$", statement, re.I | re.S):
        return None
    # Skip bare DELIMITER directives (normally consumed by split_statements)
    if re.match(r"^DELIMITER\b", statement, re.I):
        return None

    # Strip MySQL DEFINER clause from CREATE PROCEDURE/FUNCTION/TRIGGER/VIEW
    statement = DEFINER_PATTERN.sub("", statement)

    statement = convert_string_literals(statement)
    statement = statement.replace("`", '"')
    if uppercase_tables:
        statement = uppercase_table_name(statement)

    if re.match(r"^CREATE TABLE\b", statement, re.I):
        for pattern, replacement in MYSQL_TYPES:
            statement = re.sub(pattern, replacement, statement, flags=re.I)
        statement = re.sub(r"\s+UNSIGNED\b", "", statement, flags=re.I)
        statement = re.sub(r"\s+AUTO_INCREMENT(?:\s*=\s*\d+)?\b", "", statement, flags=re.I)
        statement = re.sub(r"\s+COMMENT\s+'(?:''|[^'])*'", "", statement, flags=re.I)
        statement = re.sub(r"\s+DEFAULT\s+'(-?\d+(?:\.\d+)?)'", r" DEFAULT \1", statement, flags=re.I)
        statement = re.sub(r"\s+ENGINE\s*=\s*\w+", "", statement, flags=re.I)
        statement = re.sub(r"\s+DEFAULT\s+CHARSET\s*=\s*\w+", "", statement, flags=re.I)
        statement = re.sub(r"\s+COLLATE\s*=\s*\w+", "", statement, flags=re.I)
        statement = re.sub(
            r"UNIQUE\s+KEY\s+(\"[^\"]+\")\s*(\([^)]*\))",
            r"CONSTRAINT \1 UNIQUE \2",
            statement,
            flags=re.I,
        )
        statement = quote_unicode_literals(statement)
    elif re.match(r"^CREATE\s+(?:OR\s+REPLACE\s+)?(?:PROCEDURE|FUNCTION)\b", statement, re.I):
        statement = _convert_routine(statement)

    return statement + ";"


def quote_unicode_literals(statement: str) -> str:
    """Use the Unicode literal form used by the project's HANA templates."""
    output: list[str] = []
    in_string = False
    index = 0
    while index < len(statement):
        char = statement[index]
        if char != "'":
            output.append(char)
            index += 1
            continue
        if not in_string:
            output.append("N'")
            in_string = True
            index += 1
            continue
        output.append("'")
        if index + 1 < len(statement) and statement[index + 1] == "'":
            output.append("'")
            index += 2
            continue
        in_string = False
        index += 1
    return "".join(output)


def extract_table_columns(statement: str) -> tuple[str, list[tuple[str, str]]]:
    match = re.match(
        r'^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"([^"]+)"\s*\((.*)\)$',
        statement,
        re.I | re.S,
    )
    if not match:
        return "", []
    table, body = match.groups()
    columns: list[tuple[str, str]] = []
    for line in body.splitlines():
        column = re.match(r'\s*"([^"]+)"\s+([A-Z]+)', line)
        if column:
            columns.append((column.group(1), column.group(2).upper()))
    return table, columns


def insert_table_and_values(statement: str) -> tuple[str, str] | None:
    match = re.match(r'^INSERT\s+INTO\s+"([^"]+)"\s+VALUES\s+(.*);$', statement, re.I | re.S)
    return match.groups() if match else None


def is_skipped_log_table(table: str) -> bool:
    return any(pattern.search(table) for pattern in LOG_TABLE_PATTERNS)


def strip_date_time_from_insert(statement: str, date_indexes: set[int]) -> str:
    """Remove the MySQL midnight suffix from values for HANA DATE columns."""
    if not date_indexes:
        return statement
    match = insert_table_and_values(statement)
    if not match:
        return statement
    prefix_match = re.match(r'^(INSERT\s+INTO\s+"[^"]+"\s+VALUES\s+)', statement, re.I)
    if not prefix_match:
        return statement
    prefix, values = prefix_match.group(1), match[1]
    output: list[str] = []
    field = 0
    in_string = False
    escaped = False
    value_start = 0
    tuple_depth = 0
    for index, char in enumerate(values):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                in_string = False
        elif char == "'":
            in_string = True
        elif char == "(":
            tuple_depth += 1
            if tuple_depth == 1:
                output.append(values[value_start:index])
                output.append("(")
                field = 0
                value_start = index + 1
        elif char == "," and tuple_depth == 1:
            value = values[value_start:index]
            output.append(re.sub(r" 00:00:00'$", "'", value) if field in date_indexes else value)
            output.append(",")
            field += 1
            value_start = index + 1
        elif char == ")" and tuple_depth == 1:
            value = values[value_start:index]
            output.append(re.sub(r" 00:00:00'$", "'", value) if field in date_indexes else value)
            output.append(")")
            tuple_depth = 0
            value_start = index + 1
        elif char == ")":
            tuple_depth -= 1
    output.append(values[value_start:])
    return prefix + "".join(output) + ";"


def expand_multi_row_insert(statement: str) -> list[str]:
    """Keep the dump's multi-row VALUES syntax, supported by HANA SQL."""
    match = re.match(r"^(INSERT\s+INTO\s+[^;]+?\s+VALUES\s+)(.*);$", statement, re.I | re.S)
    if not match:
        return [statement]
    prefix, values = match.groups()
    return [prefix + values + ";"]


def convert(
    source: str,
    skip_logs: bool = True,
    source_name: str = "input.sql",
    uppercase_tables: bool = True,
) -> str:
    statements = split_statements(strip_dump_comments(source))
    converted: list[str] = []
    table_date_indexes: dict[str, set[int]] = {}
    for statement in statements:
        if re.match(r"^DROP\s+(TABLE|VIEW|PROCEDURE|FUNCTION|TRIGGER|SEQUENCE|TYPE)\b", statement, re.I):
            drop_item = convert_drop_statement(statement, uppercase_tables=uppercase_tables)
            if drop_item:
                converted.append(drop_item)
            continue
        item = convert_statement(statement, uppercase_tables=uppercase_tables)
        if item:
            table_name = ""
            if item.upper().startswith("CREATE TABLE"):
                table_match = CREATE_TABLE_NAME_PATTERN.match(item)
                table_name = table_match.group(1) if table_match else ""
            elif item.upper().startswith("INSERT INTO"):
                table_info = insert_table_and_values(item)
                table_name = table_info[0] if table_info else ""
            if skip_logs and is_skipped_log_table(table_name):
                continue
            if item.upper().startswith("CREATE TABLE"):
                table, columns = extract_table_columns(item[:-1])
                table_date_indexes[table] = {index for index, (_, kind) in enumerate(columns) if kind == "DATE"}
            elif item.upper().startswith("INSERT INTO"):
                table_info = insert_table_and_values(item)
                if table_info:
                    item = strip_date_time_from_insert(item, table_date_indexes.get(table_info[0], set()))
                item = quote_unicode_literals(item)
            converted.extend(expand_multi_row_insert(item))
    header = (
        f"-- HANA SQL converted from {source_name}\n"
        "-- Generated by mysql_to_hana.py. Table names are uppercase; column names retain their original case.\n"
        if uppercase_tables
        else "-- Generated by mysql_to_hana.py. Identifiers retain their original case.\n"
        + ("-- Log tables *_SYS_BOLOGST and *_SYS_USERACTLOG were skipped.\n" if skip_logs else "-- Log tables were included.\n")
        + "-- Existing objects are dropped before recreation.\n"
        + "-- Review the target schema/user before execution.\n\n"
    )
    return header + "\n\n".join(converted) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="MySQL dump file")
    parser.add_argument("output", type=Path, help="HANA SQL output file")
    parser.add_argument(
        "--include-logs",
        action="store_true",
        help="include *_SYS_BOLogst and *_SYS_USERACTLOG tables and data (default: skip)",
    )
    parser.add_argument(
        "--keep-table-case",
        action="store_false",
        dest="uppercase_tables",
        help="keep table names in their original case (default: uppercase table names)",
    )
    args = parser.parse_args()
    if not args.input.is_file():
        parser.error(f"input file does not exist: {args.input}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        convert(
            args.input.read_text(encoding="utf-8"),
            skip_logs=not args.include_logs,
            source_name=args.input.name,
            uppercase_tables=args.uppercase_tables,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
