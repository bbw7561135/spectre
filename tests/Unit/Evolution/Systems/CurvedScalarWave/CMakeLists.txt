# Distributed under the MIT License.
# See LICENSE.txt for details.

set(LIBRARY "Test_CurvedScalarwave")

set(LIBRARY_SOURCES
  TestHelpers.cpp
  Test_DuDt.cpp
  )

add_test_library(
  ${LIBRARY}
  "Evolution/Systems/CurvedScalarWave/"
  "${LIBRARY_SOURCES}"
  "CurvedScalarWave"
  )
