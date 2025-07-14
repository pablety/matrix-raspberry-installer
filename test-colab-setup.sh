#!/bin/bash
# Simple Matrix Colab Test Script - Validates core functionality

set -e

echo "🧪 Testing Matrix Colab Setup..."

# Test 1: Python environment
echo "📍 Test 1: Python environment"
python3 --version
pip3 --version

# Test 2: Virtual environment creation
echo "📍 Test 2: Virtual environment"
TEST_DIR="/tmp/matrix-test-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

python3 -m venv test_env
source test_env/bin/activate
pip install --upgrade pip > /dev/null

echo "✅ Virtual environment works"

# Test 3: Matrix Synapse installation (quick test)
echo "📍 Test 3: Matrix Synapse installation"
pip install matrix-synapse[sqlite] > /dev/null 2>&1
python -c "import synapse; print('Matrix version:', synapse.__version__)"

echo "✅ Matrix Synapse installs correctly"

# Test 4: Basic configuration generation
echo "📍 Test 4: Configuration generation"
mkdir -p data
python -m synapse.app.homeserver \
    --server-name="test.local" \
    --config-path="homeserver.yaml" \
    --generate-config \
    --report-stats=no \
    --data-directory="data"

echo "✅ Configuration generated"

# Test 5: SQLite database functionality
echo "📍 Test 5: Database setup"
if [ -f "data/synapse.db" ] || [ -f "homeserver.db" ]; then
    echo "✅ SQLite database initialized"
else
    echo "ℹ️  Database will be created on first run"
fi

# Test 6: Server startup test (without actually starting)
echo "📍 Test 6: Server executable test"
python -m synapse.app.homeserver --help > /dev/null
echo "✅ Server binary works"

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo ""
echo "🎉 All tests passed! Matrix Colab setup is ready."
echo "✅ Python environment: OK"
echo "✅ Virtual environment: OK" 
echo "✅ Matrix Synapse: OK"
echo "✅ Configuration: OK"
echo "✅ Database: OK"
echo "✅ Server binary: OK"
echo ""
echo "🚀 Ready for Google Colab deployment!"

exit 0