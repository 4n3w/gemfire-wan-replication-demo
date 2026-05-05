#!/bin/bash
set -e

GF_LIB="/gemfire/lib"
SRC="/scripts/DataGenerator.java"
OUT="/tmp/datagen-classes"

echo "Compiling data generator..."
mkdir -p "$OUT"
javac -cp "$GF_LIB/*" "$SRC" -d "$OUT"

echo "Starting data generator..."
exec java -cp "$GF_LIB/*:$OUT" DataGenerator
