ARG FROM_IMG=tarantool/getting-started:latest

FROM $FROM_IMG

ENV CARTRIDGE_DIR=/usr/share/tarantool/try-cartridge
WORKDIR ${CARTRIDGE_DIR}

CMD bash -c "mkdir -p ${CARTRIDGE_RUN_DIR} ${CARTRIDGE_DATA_DIR} && CARTRIDGE_DIR=${CARTRIDGE_DIR} 	TARANTOOL_PID_FILE=${TARANTOOL_PID_FILE:-${CARTRIDGE_RUN_DIR}/try-cartridge.${TARANTOOL_INSTANCE_NAME}.pid} 	TARANTOOL_CONSOLE_SOCK=${TARANTOOL_CONSOLE_SOCK:-${CARTRIDGE_RUN_DIR}/try-cartridge.${TARANTOOL_INSTANCE_NAME}.control} 	cartridge start --run-dir=${CARTRIDGE_RUN_DIR} --data-dir=${CARTRIDGE_RUN_DIR} --log-dir=${CARTRIDGE_RUN_DIR}"
