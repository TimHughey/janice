idf_component_register(SRCS "main.cpp"
                       INCLUDE_DIRS "../components/mcr/include/")

target_compile_options(${COMPONENT_LIB} PRIVATE -DMG_LOCALS -DMG_ENABLE_HTTP=0 -DARDUINOJSON_ENABLE_STD_STREAM -DARDUINOJSON_USE_LONG_LONG)
