!#!/bin/bash
set -e

GF_LIB="/gemfire/lib"
SRC="/scripts/PoisonPillController.java"
OUT="/tmp/ppcontroller-classes"

echo "Compiling poison pill controller..."
mkdir -p "$OUT"
javac -cp "$GF_LIB/*" "$SRC" -d "$OUT"

echo "Starting poison pill controller..."
exec java -cp "$GF_LIB/*:$OUT" PoisonPillController
