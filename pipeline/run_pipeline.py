from pathlib import Path

import duckdb
import pandas as pd


project_folder = Path(__file__).resolve().parent.parent
excel_file = project_folder / "data" / "raw" / "2009_2025-quarterly-surgical_wait_times-final.xlsx"
csv_file = project_folder / "data" / "interim" / "surgical_wait_times_cleaned.csv"
duckdb_file = project_folder / "data" / "processed" / "surgical_wait_times.duckdb"

view_files = [
    project_folder / "sql" / "views" / "view_covid_recovery.sql",
    project_folder / "sql" / "views" / "view_regional_wait_times.sql",
    project_folder / "sql" / "views" / "view_procedure_volume_trends.sql",
    project_folder / "sql" / "views" / "view_benchmark_compliance.sql",
    project_folder / "sql" / "views" / "view_hospital_outliers.sql",
]


def load_excel():
    print("Reading the Excel file...")
    df = pd.read_excel(excel_file, engine="openpyxl")
    print(f"Raw rows: {len(df):,}")
    return df


def clean_dataframe(df):
    print("Cleaning the data...")

    text_columns = [
        "FISCAL_YEAR",
        "QUARTER",
        "HEALTH_AUTHORITY",
        "HOSPITAL_NAME",
        "PROCEDURE_GROUP",
    ]

    for column in text_columns:
        df[column] = df[column].astype(str).str.strip()

    df = df[
        (df["HOSPITAL_NAME"] != "All Facilities")
        & (df["PROCEDURE_GROUP"] != "All Procedures")
        & (df["HEALTH_AUTHORITY"] != "All Health Authorities")
    ].copy()

    df["WAITING"] = pd.to_numeric(df["WAITING"], errors="coerce").astype("Int64")
    df["COMPLETED"] = pd.to_numeric(df["COMPLETED"], errors="coerce").astype("Int64")
    df["PERCENTILE_COMP_50TH"] = pd.to_numeric(df["PERCENTILE_COMP_50TH"], errors="coerce").round(1)
    df["PERCENTILE_COMP_90TH"] = pd.to_numeric(df["PERCENTILE_COMP_90TH"], errors="coerce").round(1)

    df["percentile_suppressed"] = df["PERCENTILE_COMP_50TH"].isna()
    df["anomalous_percentile"] = df["percentile_suppressed"] & (df["COMPLETED"].fillna(0) > 0)
    df["fiscal_year_start"] = df["FISCAL_YEAR"].str[:4].astype(int)
    df["quarter_number"] = df["QUARTER"].map({"Q1": 1, "Q2": 2, "Q3": 3, "Q4": 4}).astype(int)
    df["period_sort_key"] = df["fiscal_year_start"] * 10 + df["quarter_number"]
    df["covid_flag"] = df["fiscal_year_start"].isin([2020, 2021])
    df["provisional_flag"] = df["FISCAL_YEAR"] == "2024/25"

    df = df.rename(columns=str.lower)

    print(f"Clean rows: {len(df):,}")
    return df


def save_csv(df):
    csv_file.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(csv_file, index=False, encoding="utf-8")
    print(f"CSV saved: {csv_file}")


def save_duckdb(df):
    duckdb_file.parent.mkdir(parents=True, exist_ok=True)

    if duckdb_file.exists():
        duckdb_file.unlink()

    con = duckdb.connect(str(duckdb_file))

    try:
        csv_path = str(csv_file.resolve()).replace("\\", "/")
        con.execute(
            f"""
            CREATE TABLE fact_surgical_waits AS
            SELECT *
            FROM read_csv_auto('{csv_path}', header = true)
            """
        )

        for file_path in view_files:
            sql = file_path.read_text(encoding="utf-8")
            con.execute(sql)

        print(f"DuckDB rows: {len(df):,}")
    finally:
        con.close()

    print(f"DuckDB saved: {duckdb_file}")


def main():
    print("BC Surgical Wait Times")
    print("-" * 30)

    df = load_excel()
    df = clean_dataframe(df)
    save_csv(df)
    save_duckdb(df)

    print("-" * 30)
    print("Done")
    print(f"CSV file: {csv_file}")
    print(f"DuckDB file: {duckdb_file}")
    print("Use the DuckDB file in Power BI to make charts.")


if __name__ == "__main__":
    main()
