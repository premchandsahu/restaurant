const db = require('../database');


// =========================================================
// Helper: Validate date
// =========================================================

function isValidDate(value) {
    if (!value) return false;

    const date = new Date(value);

    return !isNaN(date.getTime());
}


// =========================================================
// Helper: Check user outlet access
// =========================================================

async function getAuthorizedOutlet(
    connection,
    outletId,
    req
) {

    const [rows] = await connection.query(
        `
        SELECT
            o.outlet_id,
            o.company_id
        FROM outlet o

        INNER JOIN user_outlet uo
            ON uo.outlet_id = o.outlet_id

        WHERE o.outlet_id = ?
          AND o.company_id = ?
          AND uo.user_id = ?

        LIMIT 1
        `,
        [
            outletId,
            req.user.companyId,
            req.user.userId
        ]
    );

    return rows.length > 0
        ? rows[0]
        : null;
}


// =========================================================
// GET ROOM AVAILABILITY
//
// GET /hotel/rooms/availability
//
// Query:
//
// outletId
// roomTypeId
// fromDate
// toDate
// =========================================================

exports.getRoomAvailability = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

       const {
    outletId,
    roomTypeId,
    fromDate,
    toDate
} = req.body;

const outlet =
    Number(outletId);

const roomType =
    Number(roomTypeId);
        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        if (!outlet) {
    return res.status(400).json({
        success: false,
        message: 'Invalid outletId'
    });
}

if (!roomType) {
    return res.status(400).json({
        success: false,
        message: 'Invalid roomTypeId'
    });
}

        if (
            !isValidDate(fromDate) ||
            !isValidDate(toDate)
        ) {

            return res.status(400).json({
                success: false,
                message: 'Invalid date range'
            });

        }


        if (
            new Date(fromDate) >=
            new Date(toDate)
        ) {

            return res.status(400).json({
                success: false,
                message:
                    'Check-out must be after check-in'
            });

        }


        // -------------------------------------------------
        // Verify outlet access
        // -------------------------------------------------

        const authorizedOutlet =
    await getAuthorizedOutlet(
        connection,
        outlet,
        req
    );


        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }


        // -------------------------------------------------
        // Check room type
        // -------------------------------------------------

        const [roomTypes] =
            await connection.query(
                `
                SELECT
                    room_type_id,
                    type_code,
                    type_name,
                    capacity_adult,
                    capacity_child,
                    base_rate

                FROM room_type

                WHERE room_type_id = ?
                  AND outlet_id = ?
                  AND is_active = TRUE

                LIMIT 1
                `,
                [
                    roomType,
                    outlet
                ]
            );


        if (roomTypes.length === 0) {

            return res.status(404).json({
                success: false,
                message: 'Room type not found'
            });

        }


        const oroomType =
            roomTypes[0];


        // -------------------------------------------------
        // Get rooms which are NOT blocked by:
        //
        // 1. Existing reservation
        // 2. Existing active stay
        //
        // -------------------------------------------------

        const [rooms] =
            await connection.query(
                `
                SELECT
                    r.room_id,
                    r.room_no,
                    r.room_name,
                    r.floor_no,
                    r.status,
                    r.housekeeping_status

                FROM hotel_room r

                WHERE r.outlet_id = ?
                  AND r.room_type_id = ?
                  AND r.is_active = TRUE

                  AND r.status NOT IN
                  (
                      'MAINTENANCE',
                      'BLOCKED'
                  )

                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM hotel_reservation hr

                      WHERE hr.room_id = r.room_id

                        AND hr.status IN
                        (
                            'CONFIRMED',
                            'TENTATIVE',
                            'CHECKED_IN'
                        )

                        AND hr.expected_check_in < ?
                        AND hr.expected_check_out > ?
                  )

                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM hotel_stay hs

                      WHERE hs.room_id = r.room_id

                        AND hs.status = 'CHECKED_IN'

                        AND hs.check_in < ?
                        AND COALESCE(
                            hs.actual_check_out,
                            '9999-12-31'
                        ) > ?
                  )

                ORDER BY
                    r.room_no
                `,
                [
                    outlet,
                    roomType,

                    toDate,
                    fromDate,

                    toDate,
                    fromDate
                ]
            );


        return res.json({

            success: true,

            roomType: {
                roomTypeId:
                    oroomType.room_type_id,

                typeCode:
                    oroomType.type_code,

                typeName:
                    oroomType.type_name,

                capacityAdult:
                    oroomType.capacity_adult,

                capacityChild:
                    oroomType.capacity_child,

                baseRate:
                    oroomType.base_rate
            },

            availableRooms:
                rooms.map(room => ({

                    roomId:
                        room.room_id,

                    roomNo:
                        room.room_no,

                    roomName:
                        room.room_name,

                    floorNo:
                        room.floor_no,

                    status:
                        room.status,

                    housekeepingStatus:
                        room.housekeeping_status

                })),

            count:
                rooms.length

        });


    } catch (error) {

        console.error(
            'Get room availability error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get room availability'
        });

    } finally {

        connection.release();

    }
};


// =========================================================
// CREATE RESERVATION
//
// POST /hotel/reservations
// =========================================================

exports.createReservation = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const {
            outletId,
            guestId,
            roomTypeId,
            roomId = null,
            expectedCheckIn,
            expectedCheckOut,
            adults = 1,
            children = 0,
            roomRate,
            advanceAmount = 0,
            bookingSource = 'DIRECT',
            remarks = null
        } = req.body;


        const outlet =
            Number(outletId);

        const guest =
            Number(guestId);

        const roomType =
            Number(roomTypeId);

        const selectedRoom =
            roomId
                ? Number(roomId)
                : null;


        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        if (!outlet) {

            return res.status(400).json({
                success: false,
                message: 'Invalid outletId'
            });

        }

        if (!guest) {

            return res.status(400).json({
                success: false,
                message: 'Invalid guestId'
            });

        }

        if (!roomType) {

            return res.status(400).json({
                success: false,
                message: 'Invalid roomTypeId'
            });

        }

        if (
            !isValidDate(expectedCheckIn) ||
            !isValidDate(expectedCheckOut)
        ) {

            return res.status(400).json({
                success: false,
                message: 'Invalid check-in/check-out'
            });

        }

        if (
            new Date(expectedCheckIn) >=
            new Date(expectedCheckOut)
        ) {

            return res.status(400).json({
                success: false,
                message:
                    'Check-out must be after check-in'
            });

        }


        // -------------------------------------------------
        // Authorization
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outlet,
                req
            );


        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }


        await connection.beginTransaction();


        // -------------------------------------------------
        // Lock guest
        // -------------------------------------------------

        const [guests] =
            await connection.query(
                `
                SELECT
                    guest_id,
                    outlet_id

                FROM hotel_guest

                WHERE guest_id = ?
                  AND outlet_id = ?
                  AND is_active = TRUE

                FOR UPDATE
                `,
                [
                    guest,
                    outlet
                ]
            );


        if (guests.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Guest not found'
            });

        }


        // -------------------------------------------------
        // Lock room type
        // -------------------------------------------------

        const [roomTypes] =
            await connection.query(
                `
                SELECT
                    room_type_id,
                    type_code,
                    type_name,
                    base_rate

                FROM room_type

                WHERE room_type_id = ?
                  AND outlet_id = ?
                  AND is_active = TRUE

                FOR UPDATE
                `,
                [
                    roomType,
                    outlet
                ]
            );


        if (roomTypes.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Room type not found'
            });

        }


        // -------------------------------------------------
        // If specific room supplied
        // -------------------------------------------------

        if (selectedRoom) {

            const [rooms] =
                await connection.query(
                    `
                    SELECT
                        room_id,
                        room_type_id,
                        room_no,
                        status

                    FROM hotel_room

                    WHERE room_id = ?
                      AND outlet_id = ?
                      AND is_active = TRUE

                    FOR UPDATE
                    `,
                    [
                        selectedRoom,
                        outlet
                    ]
                );


            if (rooms.length === 0) {

                await connection.rollback();

                return res.status(404).json({
                    success: false,
                    message: 'Room not found'
                });

            }


            const room =
                rooms[0];


            if (
                Number(room.room_type_id) !==
                roomType
            ) {

                await connection.rollback();

                return res.status(400).json({
                    success: false,
                    message:
                        'Room does not belong to selected room type'
                });

            }


            if (
                [
                    'MAINTENANCE',
                    'BLOCKED'
                ].includes(room.status)
            ) {

                await connection.rollback();

                return res.status(409).json({
                    success: false,
                    message:
                        `Room ${room.room_no} is currently ${room.status}`
                });

            }


            // ---------------------------------------------
            // Check reservation overlap
            // ---------------------------------------------

            const [existingReservations] =
                await connection.query(
                    `
                    SELECT
                        reservation_id

                    FROM hotel_reservation

                    WHERE room_id = ?

                      AND status IN
                      (
                          'CONFIRMED',
                          'TENTATIVE',
                          'CHECKED_IN'
                      )

                      AND expected_check_in < ?
                      AND expected_check_out > ?

                    LIMIT 1

                    FOR UPDATE
                    `,
                    [
                        selectedRoom,
                        expectedCheckOut,
                        expectedCheckIn
                    ]
                );


            if (
                existingReservations.length > 0
            ) {

                await connection.rollback();

                return res.status(409).json({
                    success: false,
                    message:
                        'Room is already reserved for the selected dates'
                });

            }


            // ---------------------------------------------
            // Check active stay
            // ---------------------------------------------

            const [activeStays] =
                await connection.query(
                    `
                    SELECT
                        stay_id

                    FROM hotel_stay

                    WHERE room_id = ?

                      AND status = 'CHECKED_IN'

                      AND check_in < ?
                      AND COALESCE(
                          actual_check_out,
                          '9999-12-31'
                      ) > ?

                    LIMIT 1

                    FOR UPDATE
                    `,
                    [
                        selectedRoom,
                        expectedCheckOut,
                        expectedCheckIn
                    ]
                );


            if (activeStays.length > 0) {

                await connection.rollback();

                return res.status(409).json({
                    success: false,
                    message:
                        'Room is occupied during the selected period'
                });

            }

        }


        // -------------------------------------------------
        // Generate reservation number
        // -------------------------------------------------

        const reservationNo =
            await generateReservationNo(
                connection,
                outlet
            );


        // -------------------------------------------------
        // Insert reservation
        // -------------------------------------------------

        const [result] =
            await connection.query(
                `
                INSERT INTO hotel_reservation
                (
                    outlet_id,
                    reservation_no,
                    guest_id,
                    room_type_id,
                    room_id,
                    booking_date,
                    expected_check_in,
                    expected_check_out,
                    adults,
                    children,
                    room_rate,
                    advance_amount,
                    status,
                    booking_source,
                    remarks,
                    created_by,
                    updated_by
                )

                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    NOW(),
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    'CONFIRMED',
                    ?,
                    ?,
                    ?,
                    ?
                )
                `,
                [
                    outlet,
                    reservationNo,
                    guest,
                    roomType,
                    selectedRoom,

                    expectedCheckIn,
                    expectedCheckOut,

                    Number(adults),
                    Number(children),

                    Number(roomRate || 0),
                    Number(advanceAmount || 0),

                    bookingSource,
                    remarks,

                    req.user.userId,
                    req.user.userId
                ]
            );


        const reservationId =
            result.insertId;


        // -------------------------------------------------
        // If room assigned, update room status
        // -------------------------------------------------

        if (selectedRoom) {

            await connection.query(
                `
                UPDATE hotel_room

                SET
                    status = 'RESERVED',
                    updated_by = ?,
                    updated_at = NOW()

                WHERE room_id = ?
                  AND outlet_id = ?
                `,
                [
                    req.user.userId,
                    selectedRoom,
                    outlet
                ]
            );

        }


        await connection.commit();


        return res.status(201).json({

            success: true,

            reservation: {
                reservationId,
                reservationNo,
                guestId: guest,
                roomTypeId: roomType,
                roomId: selectedRoom,
                expectedCheckIn,
                expectedCheckOut,
                status: 'CONFIRMED'
            }

        });


    } catch (error) {

        await connection.rollback();

        console.error(
            'Create reservation error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to create reservation'
        });

    } finally {

        connection.release();

    }
};


// =========================================================
// GENERATE RESERVATION NUMBER
// =========================================================

async function generateReservationNo(
    connection,
    outletId
) {

    const [rows] =
        await connection.query(
            `
            SELECT
                sequence_id,
                last_number

            FROM hotel_document_sequence

            WHERE outlet_id = ?
              AND document_type = 'RESERVATION'

            FOR UPDATE
            `,
            [outletId]
        );


    if (rows.length === 0) {

        await connection.query(
            `
            INSERT INTO hotel_document_sequence
            (
                outlet_id,
                document_type,
                last_number
            )
            VALUES
            (
                ?,
                'RESERVATION',
                1
            )
            `,
            [outletId]
        );

        return 'RES-000001';
    }


    const nextNumber =
        Number(rows[0].last_number) + 1;


    await connection.query(
        `
        UPDATE hotel_document_sequence

        SET last_number = ?

        WHERE sequence_id = ?
        `,
        [
            nextNumber,
            rows[0].sequence_id
        ]
    );


    return `RES-${String(nextNumber).padStart(6, '0')}`;
}

// =========================================================
// GET RESERVATION
//
// GET /hotel/reservations/:reservationId
// =========================================================

exports.getReservation = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const reservationId =
            Number(req.params.reservationId);


        if (!reservationId) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid reservationId'
            });

        }


        const [rows] =
            await connection.query(
                `
                SELECT
                    hr.*,

                    hg.guest_code,
                    hg.first_name,
                    hg.last_name,
                    hg.phone,
                    hg.email,

                    rt.type_code,
                    rt.type_name,

                    r.room_no,
                    r.room_name

                FROM hotel_reservation hr

                INNER JOIN outlet o
                    ON o.outlet_id =
                       hr.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       hr.outlet_id

                INNER JOIN hotel_guest hg
                    ON hg.guest_id =
                       hr.guest_id

                INNER JOIN room_type rt
                    ON rt.room_type_id =
                       hr.room_type_id

                LEFT JOIN hotel_room r
                    ON r.room_id =
                       hr.room_id

                WHERE hr.reservation_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    reservationId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (rows.length === 0) {

            return res.status(404).json({
                success: false,
                message:
                    'Reservation not found'
            });

        }


        return res.json({

            success: true,

            reservation:
                rows[0]

        });


    } catch (error) {

        console.error(
            'Get reservation error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get reservation'
        });

    } finally {

        connection.release();

    }
};


// =========================================================
// UPDATE RESERVATION
//
// PUT /hotel/reservations/:reservationId
// =========================================================

exports.updateReservation = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const reservationId =
            Number(req.params.reservationId);


        if (!reservationId) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid reservationId'
            });

        }


        const {
            roomTypeId = null,
            roomId = null,
            expectedCheckIn,
            expectedCheckOut,
            adults = 1,
            children = 0,
            roomRate = 0,
            advanceAmount = 0,
            bookingSource = 'DIRECT',
            remarks = null
        } = req.body;


        if (
            !isValidDate(expectedCheckIn) ||
            !isValidDate(expectedCheckOut)
        ) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid check-in/check-out'
            });

        }


        if (
            new Date(expectedCheckIn) >=
            new Date(expectedCheckOut)
        ) {

            return res.status(400).json({
                success: false,
                message:
                    'Check-out must be after check-in'
            });

        }


        await connection.beginTransaction();


        // -------------------------------------------------
        // Lock reservation + authorization
        // -------------------------------------------------

        const [reservations] =
            await connection.query(
                `
                SELECT
                    hr.*

                FROM hotel_reservation hr

                INNER JOIN outlet o
                    ON o.outlet_id =
                       hr.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       hr.outlet_id

                WHERE hr.reservation_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    reservationId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (reservations.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message:
                    'Reservation not found'
            });

        }


        const reservation =
            reservations[0];


        // -------------------------------------------------
        // Only tentative/confirmed can be changed
        // -------------------------------------------------

        if (
            ![
                'TENTATIVE',
                'CONFIRMED'
            ].includes(
                reservation.status
            )
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot update ${reservation.status} reservation`
            });

        }


        const newRoomTypeId =
            roomTypeId === null ||
            roomTypeId === undefined
                ? Number(reservation.room_type_id)
                : Number(roomTypeId);

        const newRoomId =
            roomId === null ||
            roomId === undefined
                ? (
                    Number(newRoomTypeId) ===
                    Number(reservation.room_type_id)
                        ? reservation.room_id
                        : null
                )
                : (
                    Number(roomId) > 0
                        ? Number(roomId)
                        : null
                );

        const [roomTypes] =
            await connection.query(
                `
                SELECT
                    room_type_id
                FROM room_type
                WHERE room_type_id = ?
                  AND outlet_id = ?
                  AND is_active = TRUE
                LIMIT 1
                `,
                [
                    newRoomTypeId,
                    reservation.outlet_id
                ]
            );
        
        if (roomTypes.length === 0) {
        
            await connection.rollback();
        
            return res.status(404).json({
                success: false,
                message:
                    'Room type not found'
            });
        }
        // -------------------------------------------------
        // Check new room
        // -------------------------------------------------

        if (newRoomId) {

            const [rooms] =
                await connection.query(
                    `
                    SELECT
                        room_id,
                        room_type_id,
                        status

                    FROM hotel_room

                    WHERE room_id = ?
                      AND outlet_id = ?
                      AND is_active = TRUE

                    FOR UPDATE
                    `,
                    [
                        newRoomId,
                        reservation.outlet_id
                    ]
                );


            if (rooms.length === 0) {

                await connection.rollback();

                return res.status(404).json({
                    success: false,
                    message:
                        'Room not found'
                });

            }


            if (
                Number(
                    rooms[0].room_type_id
                ) !==
                Number(
                    newRoomTypeId
                )
            ) {

                await connection.rollback();

                return res.status(400).json({
                    success: false,
                    message:
                        'Room does not belong to reservation room type'
                });

            }


            if (
                [
                    'MAINTENANCE',
                    'BLOCKED'
                ].includes(
                    rooms[0].status
                )
            ) {

                await connection.rollback();

                return res.status(409).json({
                    success: false,
                    message:
                        'Selected room is unavailable'
                });

            }


            const [conflicts] =
                await connection.query(
                    `
                    SELECT
                        reservation_id

                    FROM hotel_reservation

                    WHERE room_id = ?

                      AND reservation_id <> ?

                      AND status IN
                      (
                          'CONFIRMED',
                          'TENTATIVE',
                          'CHECKED_IN'
                      )

                      AND expected_check_in < ?
                      AND expected_check_out > ?

                    LIMIT 1

                    FOR UPDATE
                    `,
                    [
                        newRoomId,
                        reservationId,
                        expectedCheckOut,
                        expectedCheckIn
                    ]
                );


            if (conflicts.length > 0) {

                await connection.rollback();

                return res.status(409).json({
                    success: false,
                    message:
                        'Selected room is already reserved'
                });

            }

        }


        // -------------------------------------------------
        // Release old room if changed
        // -------------------------------------------------

        if (
            reservation.room_id &&
            Number(reservation.room_id) !==
            Number(newRoomId)
        ) {

            await connection.query(
                `
                UPDATE hotel_room

                SET
                    status = 'AVAILABLE',
                    updated_by = ?,
                    updated_at = NOW()

                WHERE room_id = ?
                  AND outlet_id = ?
                `,
                [
                    req.user.userId,
                    reservation.room_id,
                    reservation.outlet_id
                ]
            );

        }


        // -------------------------------------------------
        // Update reservation
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_reservation

            SET
                room_type_id=?,
                room_id = ?,
                expected_check_in = ?,
                expected_check_out = ?,
                adults = ?,
                children = ?,
                room_rate = ?,
                advance_amount = ?,
                booking_source = ?,
                remarks = ?,
                updated_by = ?,
                updated_at = NOW()

            WHERE reservation_id = ?
            `,
            [
                newRoomTypeId,
                newRoomId,

                expectedCheckIn,
                expectedCheckOut,

                Number(adults),
                Number(children),

                Number(roomRate),
                Number(advanceAmount),

                bookingSource,
                remarks,

                req.user.userId,

                reservationId
            ]
        );


        // -------------------------------------------------
        // Reserve new room
        // -------------------------------------------------

        if (newRoomId) {

            await connection.query(
                `
                UPDATE hotel_room

                SET
                    status = 'RESERVED',
                    updated_by = ?,
                    updated_at = NOW()

                WHERE room_id = ?
                  AND outlet_id = ?
                `,
                [
                    req.user.userId,
                    newRoomId,
                    reservation.outlet_id
                ]
            );

        }


        await connection.commit();


        return res.json({

            success: true,

            message:
                'Reservation updated successfully',

            reservationId

        });


    } catch (error) {

        await connection.rollback();

        console.error(
            'Update reservation error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to update reservation'
        });

    } finally {

        connection.release();

    }
};


// =========================================================
// CANCEL RESERVATION
//
// POST /hotel/reservations/:reservationId/cancel
// =========================================================

exports.cancelReservation = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const reservationId =
            Number(req.params.reservationId);


        if (!reservationId) {

            return res.status(400).json({
                success: false,
                message:
                    'Invalid reservationId'
            });

        }


        await connection.beginTransaction();


        // -------------------------------------------------
        // Lock reservation
        // -------------------------------------------------

        const [reservations] =
            await connection.query(
                `
                SELECT
                    hr.*

                FROM hotel_reservation hr

                INNER JOIN outlet o
                    ON o.outlet_id =
                       hr.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       hr.outlet_id

                WHERE hr.reservation_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    reservationId,
                    req.user.companyId,
                    req.user.userId
                ]
            );


        if (reservations.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message:
                    'Reservation not found'
            });

        }


        const reservation =
            reservations[0];


        if (
            ![
                'TENTATIVE',
                'CONFIRMED'
            ].includes(
                reservation.status
            )
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Cannot cancel ${reservation.status} reservation`
            });

        }


        // -------------------------------------------------
        // Cancel reservation
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_reservation

            SET
                status = 'CANCELLED',
                updated_by = ?,
                updated_at = NOW()

            WHERE reservation_id = ?
            `,
            [
                req.user.userId,
                reservationId
            ]
        );


        // -------------------------------------------------
        // Release assigned room
        // -------------------------------------------------

        if (reservation.room_id) {

            await connection.query(
                `
                UPDATE hotel_room

                SET
                    status = 'AVAILABLE',
                    updated_by = ?,
                    updated_at = NOW()

                WHERE room_id = ?
                  AND outlet_id = ?
                `,
                [
                    req.user.userId,
                    reservation.room_id,
                    reservation.outlet_id
                ]
            );

        }


        await connection.commit();


        return res.json({

            success: true,

            message:
                'Reservation cancelled successfully',

            reservationId

        });


    } catch (error) {

        await connection.rollback();

        console.error(
            'Cancel reservation error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to cancel reservation'
        });

    } finally {

        connection.release();

    }
};

// =========================================================
// CHECK-IN
//
// POST /hotel/stays/check-in
// =========================================================

exports.checkIn = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const {
            outletId,
            reservationId,
            roomId = null,
            checkIn = null
        } = req.body;

        const outlet = Number(outletId);
        const reservation = Number(reservationId);
        const selectedRoom = roomId
            ? Number(roomId)
            : null;

        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        if (!outlet) {
            return res.status(400).json({
                success: false,
                message: 'Invalid outletId'
            });
        }

        if (!reservation) {
            return res.status(400).json({
                success: false,
                message: 'Invalid reservationId'
            });
        }

        // -------------------------------------------------
        // Authorization
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outlet,
                req
            );

        if (!authorizedOutlet) {
            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Lock reservation
        // -------------------------------------------------

        const [reservations] =
            await connection.query(
                `
                SELECT
                    hr.*,

                    hg.first_name,
                    hg.last_name,
                    hg.phone,

                    rt.type_code,
                    rt.type_name,

                    r.room_no

                FROM hotel_reservation hr

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hr.guest_id

                INNER JOIN room_type rt
                    ON rt.room_type_id =
                       hr.room_type_id

                LEFT JOIN hotel_room r
                    ON r.room_id = hr.room_id

                WHERE hr.reservation_id = ?
                  AND hr.outlet_id = ?

                FOR UPDATE
                `,
                [
                    reservation,
                    outlet
                ]
            );

        if (reservations.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Reservation not found'
            });
        }

        const reservationData =
            reservations[0];

        // -------------------------------------------------
        // Reservation must be CONFIRMED
        // -------------------------------------------------

        if (reservationData.status !== 'CONFIRMED') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Reservation cannot be checked in because its status is ${reservationData.status}`
            });
        }

        // -------------------------------------------------
        // Determine room
        //
        // If reservation already has a room,
        // use it unless another room was supplied.
        // -------------------------------------------------

        const finalRoomId =
            selectedRoom ||
            Number(reservationData.room_id);

        if (!finalRoomId) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'No room assigned to this reservation'
            });
        }

        // -------------------------------------------------
        // Lock room
        // -------------------------------------------------

        const [rooms] =
            await connection.query(
                `
                SELECT
                    room_id,
                    outlet_id,
                    room_type_id,
                    room_no,
                    status,
                    housekeeping_status

                FROM hotel_room

                WHERE room_id = ?
                  AND outlet_id = ?
                  AND is_active = TRUE

                FOR UPDATE
                `,
                [
                    finalRoomId,
                    outlet
                ]
            );

        if (rooms.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Room not found'
            });
        }

        const room = rooms[0];

        // -------------------------------------------------
        // Verify room type
        // -------------------------------------------------

        if (
            Number(room.room_type_id) !==
            Number(reservationData.room_type_id)
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Selected room does not belong to reservation room type'
            });
        }

        // -------------------------------------------------
        // Room must not already be occupied
        // -------------------------------------------------

        if (
            [
                'OCCUPIED',
                'MAINTENANCE',
                'BLOCKED'
            ].includes(room.status)
        ) {

            await connection.rollback();

            return res.status(409).json({
                success: false,
                message:
                    `Room ${room.room_no} is currently ${room.status}`
            });
        }

        // -------------------------------------------------
        // Housekeeping check
        // -------------------------------------------------

        if (
            room.housekeeping_status ===
            'OUT_OF_ORDER'
        ) {

            await connection.rollback();

            return res.status(409).json({
                success: false,
                message:
                    `Room ${room.room_no} is out of order`
            });
        }

        // -------------------------------------------------
        // Check existing active stay
        // -------------------------------------------------

        const [activeStays] =
            await connection.query(
                `
                SELECT
                    stay_id,
                    stay_no

                FROM hotel_stay

                WHERE room_id = ?

                  AND status = 'CHECKED_IN'

                LIMIT 1

                FOR UPDATE
                `,
                [
                    finalRoomId
                ]
            );

        if (activeStays.length > 0) {

            await connection.rollback();

            return res.status(409).json({
                success: false,
                message:
                    `Room ${room.room_no} already has an active stay`
            });
        }

        // -------------------------------------------------
        // Generate stay number
        // -------------------------------------------------

        const stayNo =
            await generateStayNo(
                connection,
                outlet
            );

        // -------------------------------------------------
        // Actual check-in time
        // -------------------------------------------------

        const actualCheckIn =
            checkIn && isValidDate(checkIn)
                ? checkIn
                : new Date();

        // -------------------------------------------------
        // Create hotel stay
        // -------------------------------------------------

        const [stayResult] =
            await connection.query(
                `
                INSERT INTO hotel_stay
                (
                    outlet_id,
                    guest_id,
                    room_id,
                    reservation_id,
                    stay_no,
                    check_in,
                    expected_check_out,
                    adults,
                    children,
                    room_rate,
                    status,
                    remarks,
                    created_by,
                    updated_by
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    'CHECKED_IN',
                    ?,
                    ?,
                    ?
                )
                `,
                [
                    outlet,

                    reservationData.guest_id,

                    finalRoomId,

                    reservation,

                    stayNo,

                    actualCheckIn,

                    reservationData.expected_check_out,

                    reservationData.adults,

                    reservationData.children,

                    reservationData.room_rate,

                    reservationData.remarks,

                    req.user.userId,

                    req.user.userId
                ]
            );

        const stayId =
            stayResult.insertId;

        // -------------------------------------------------
        // Create stay-room history
        // -------------------------------------------------

        await connection.query(
            `
            INSERT INTO hotel_stay_room
            (
                stay_id,
                room_id,
                assigned_from,
                reason,
                created_by
            )
            VALUES
            (
                ?,
                ?,
                ?,
                'CHECK_IN',
                ?
            )
            `,
            [
                stayId,
                finalRoomId,
                actualCheckIn,
                req.user.userId
            ]
        );

        // -------------------------------------------------
        // Update reservation
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_reservation

            SET
                room_id = ?,
                status = 'CHECKED_IN',
                updated_by = ?,
                updated_at = NOW()

            WHERE reservation_id = ?
            `,
            [
                finalRoomId,
                req.user.userId,
                reservation
            ]
        );

        // -------------------------------------------------
        // Update room
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_room

            SET
                status = 'OCCUPIED',
                housekeeping_status = 'CLEAN',
                updated_by = ?,
                updated_at = NOW()

            WHERE room_id = ?
              AND outlet_id = ?
            `,
            [
                req.user.userId,
                finalRoomId,
                outlet
            ]
        );

        await connection.commit();

        return res.status(201).json({

            success: true,

            message:
                'Guest checked in successfully',

            stay: {
                stayId,
                stayNo,

                reservationId:
                    reservation,

                guestId:
                    reservationData.guest_id,

                roomId:
                    finalRoomId,

                roomNo:
                    room.room_no,

                checkIn:
                    actualCheckIn,

                expectedCheckOut:
                    reservationData.expected_check_out,

                adults:
                    reservationData.adults,

                children:
                    reservationData.children,

                roomRate:
                    reservationData.room_rate,

                status:
                    'CHECKED_IN'
            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Check-in error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to check in guest'
        });

    } finally {

        connection.release();
    }
};


// =========================================================
// GENERATE STAY NUMBER
// =========================================================

async function generateStayNo(
    connection,
    outletId
) {

    const [rows] =
        await connection.query(
            `
            SELECT
                sequence_id,
                last_number

            FROM hotel_document_sequence

            WHERE outlet_id = ?
              AND document_type = 'STAY'

            FOR UPDATE
            `,
            [
                outletId
            ]
        );

    if (rows.length === 0) {

        await connection.query(
            `
            INSERT INTO hotel_document_sequence
            (
                outlet_id,
                document_type,
                last_number
            )
            VALUES
            (
                ?,
                'STAY',
                1
            )
            `,
            [
                outletId
            ]
        );

        return 'STAY-000001';
    }

    const nextNumber =
        Number(rows[0].last_number) + 1;

    await connection.query(
        `
        UPDATE hotel_document_sequence

        SET last_number = ?

        WHERE sequence_id = ?
        `,
        [
            nextNumber,
            rows[0].sequence_id
        ]
    );

    return `STAY-${String(nextNumber).padStart(6, '0')}`;
}

// =========================================================
// CREATE GUEST ACCESS CREDENTIAL
//
// POST /hotel/stays/:stayId/credential
// =========================================================

exports.createGuestCredential = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        console.log(req.user);

        const {
            credentialType = 'BLE',
            validFrom = null,
            validUntil = null
        } = req.body;

        if (!stayId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        const allowedTypes = [
            'RFID',
            'BLE',
            'PIN'
        ];

        if (!allowedTypes.includes(credentialType)) {
            return res.status(400).json({
                success: false,
                message:
                    'Invalid guest credential type'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Get authorized stay
        // -------------------------------------------------

        const [stays] =
            await connection.query(
                `
                SELECT
                    hs.stay_id,
                    hs.outlet_id,
                    hs.guest_id,
                    hs.room_id,
                    hs.check_in,
                    hs.expected_check_out,
                    hs.status,

                    r.room_no

                FROM hotel_stay hs

                INNER JOIN outlet o
                    ON o.outlet_id = hs.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hs.outlet_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                WHERE hs.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (stays.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Stay not found'
            });
        }

        const stay = stays[0];

        // -------------------------------------------------
        // Stay must be active
        // -------------------------------------------------

        if (stay.status !== 'CHECKED_IN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Credential cannot be created for ${stay.status} stay`
            });
        }

        // -------------------------------------------------
        // Default validity
        //
        // Start = actual check-in
        // End   = expected check-out
        // -------------------------------------------------

        const credentialValidFrom =
            validFrom || stay.check_in;

        const credentialValidUntil =
            validUntil || stay.expected_check_out;

        // -------------------------------------------------
        // Generate software credential
        // -------------------------------------------------

        const credentialReference =
            generateGuestCredential(
                credentialType
            );

        // -------------------------------------------------
        // Insert credential
        // -------------------------------------------------

        const [result] =
            await connection.query(
                `
                INSERT INTO hotel_access_credential
                (
                    outlet_id,
                    room_id,
                    guest_id,
                    stay_id,
                    credential_type,
                    credential_reference,
                    valid_from,
                    valid_until,
                    status,
                    created_by
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    'ACTIVE',
                    ?
                )
                `,
                [
                    stay.outlet_id,
                    stay.room_id,
                    stay.guest_id,
                    stay.stay_id,
                    credentialType,
                    credentialReference,
                    credentialValidFrom,
                    credentialValidUntil,
                    req.user.userId
                ]
            );

        const credentialId =
            result.insertId;

        await connection.commit();

        return res.status(201).json({

            success: true,

            message:
                'Guest access credential created successfully',

            credential: {
                credentialId,
                stayId: stay.stay_id,
                guestId: stay.guest_id,
                roomId: stay.room_id,
                roomNo: stay.room_no,

                credentialType,

                credentialReference,

                validFrom:
                    credentialValidFrom,

                validUntil:
                    credentialValidUntil,

                status: 'ACTIVE'
            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Create guest credential error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to create guest credential'
        });

    } finally {

        connection.release();
    }
};

function generateGuestCredential(type) {

    const crypto = require('crypto');

    const randomPart =
        crypto.randomBytes(8)
            .toString('hex')
            .toUpperCase();

    return `GUEST-${type}-${randomPart}`;
}


// =========================================================
// GET STAY CREDENTIALS
//
// GET /hotel/stays/:stayId/credentials
// =========================================================

exports.getStayCredentials = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        if (!stayId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        const [credentials] =
            await connection.query(
                `
                SELECT
                    hac.credential_id,
                    hac.outlet_id,
                    hac.room_id,
                    hac.guest_id,
                    hac.stay_id,
                    hac.credential_type,
                    hac.credential_reference,
                    hac.valid_from,
                    hac.valid_until,
                    hac.status,
                    hac.issued_at,
                    hac.revoked_at

                FROM hotel_access_credential hac

                INNER JOIN outlet o
                    ON o.outlet_id =
                       hac.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       hac.outlet_id

                WHERE hac.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                ORDER BY
                    hac.credential_id DESC
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        return res.json({

            success: true,

            stayId,

            credentials

        });

    } catch (error) {

        console.error(
            'Get stay credentials error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get stay credentials'
        });

    } finally {

        connection.release();
    }
};

// =========================================================
// REVOKE ACCESS CREDENTIAL
//
// POST /hotel/credentials/:credentialId/revoke
// =========================================================

exports.revokeCredential = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const credentialId =
            Number(req.params.credentialId);

        if (!credentialId) {
            return res.status(400).json({
                success: false,
                message:
                    'Invalid credentialId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Lock credential + authorization
        // -------------------------------------------------

        const [credentials] =
            await connection.query(
                `
                SELECT
                    hac.*

                FROM hotel_access_credential hac

                INNER JOIN outlet o
                    ON o.outlet_id =
                       hac.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id =
                       hac.outlet_id

                WHERE hac.credential_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    credentialId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (credentials.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message:
                    'Credential not found'
            });
        }

        const credential =
            credentials[0];

        if (credential.status !== 'ACTIVE') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Credential is already ${credential.status}`
            });
        }

        // -------------------------------------------------
        // Revoke
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_access_credential

            SET
                status = 'REVOKED',
                revoked_at = NOW(),
                revoked_by = ?,
                updated_at = NOW()

            WHERE credential_id = ?
            `,
            [
                req.user.userId,
                credentialId
            ]
        );

        await connection.commit();

        return res.json({

            success: true,

            message:
                'Credential revoked successfully',

            credentialId,

            status: 'REVOKED'

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Revoke credential error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to revoke credential'
        });

    } finally {

        connection.release();
    }
};


// =========================================================
// CHECK-OUT
//
// POST /hotel/stays/:stayId/check-out
// =========================================================
/*
exports.checkOut = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        if (!stayId) {
            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Lock active stay and verify authorization
        // -------------------------------------------------

        const [stays] =
            await connection.query(
                `
                SELECT
                    hs.*,
                    r.room_no

                FROM hotel_stay hs

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                INNER JOIN outlet o
                    ON o.outlet_id = hs.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hs.outlet_id

                WHERE hs.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (stays.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Stay not found'
            });
        }

        const stay = stays[0];

        // -------------------------------------------------
        // Stay must be CHECKED_IN
        // -------------------------------------------------

        if (stay.status !== 'CHECKED_IN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Stay cannot be checked out because its status is ${stay.status}`
            });
        }

        // -------------------------------------------------
        // Check-out time
        // -------------------------------------------------

        const checkOutTime =
            req.body.checkOut &&
            isValidDate(req.body.checkOut)
                ? req.body.checkOut
                : new Date();

        // -------------------------------------------------
        // Revoke all active guest credentials
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_access_credential

            SET
                status = 'REVOKED',
                revoked_at = ?,
                revoked_by = ?,
                updated_at = NOW()

            WHERE stay_id = ?
              AND status = 'ACTIVE'
            `,
            [
                checkOutTime,
                req.user.userId,
                stayId
            ]
        );

        // -------------------------------------------------
        // Close current stay-room assignment
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_stay_room

            SET
                assigned_until = ?

            WHERE stay_id = ?
              AND assigned_until IS NULL
            `,
            [
                checkOutTime,
                stayId
            ]
        );

        // -------------------------------------------------
        // Close hotel stay
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_stay

            SET
                actual_check_out = ?,
                status = 'CHECKED_OUT',
                updated_by = ?,
                updated_at = NOW()

            WHERE stay_id = ?
            `,
            [
                checkOutTime,
                req.user.userId,
                stayId
            ]
        );

        // -------------------------------------------------
        // Complete reservation
        // -------------------------------------------------

        if (stay.reservation_id) {

            await connection.query(
                `
                UPDATE hotel_reservation

                SET
                    status = 'COMPLETED',
                    updated_by = ?,
                    updated_at = NOW()

                WHERE reservation_id = ?
                  AND status = 'CHECKED_IN'
                `,
                [
                    req.user.userId,
                    stay.reservation_id
                ]
            );
        }

        // -------------------------------------------------
        // Room → CLEANING / DIRTY
        //
        // Do NOT make it AVAILABLE immediately.
        // Housekeeping must process it first.
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_room

            SET
                status = 'CLEANING',
                housekeeping_status = 'DIRTY',
                updated_by = ?,
                updated_at = NOW()

            WHERE room_id = ?
              AND outlet_id = ?
            `,
            [
                req.user.userId,
                stay.room_id,
                stay.outlet_id
            ]
        );

        await connection.commit();

        return res.json({

            success: true,

            message:
                'Guest checked out successfully',

            stay: {
                stayId: stay.stay_id,

                stayNo:
                    stay.stay_no,

                reservationId:
                    stay.reservation_id,

                guestId:
                    stay.guest_id,

                roomId:
                    stay.room_id,

                roomNo:
                    stay.room_no,

                checkOut:
                    checkOutTime,

                status:
                    'CHECKED_OUT'
            },

            room: {
                roomId:
                    stay.room_id,

                roomNo:
                    stay.room_no,

                status:
                    'CLEANING',

                housekeepingStatus:
                    'DIRTY'
            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Check-out error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to check out guest'
        });

    } finally {

        connection.release();
    }
};
*/

// =========================================================
// HOUSEKEEPING START
//
// POST /hotel/rooms/:roomId/housekeeping-start
// =========================================================

// =========================================================
// HOUSEKEEPING START
//
// POST /hotel/rooms/:roomId/housekeeping-start
// =========================================================

exports.housekeepingStart = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const roomId =
            Number(req.params.roomId);

        if (!roomId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid roomId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Get authorized room and lock it
        // -------------------------------------------------

        const [rooms] =
            await connection.query(
                `
                SELECT
                    r.room_id,
                    r.outlet_id,
                    r.room_no,
                    r.status,
                    r.housekeeping_status

                FROM hotel_room r

                INNER JOIN outlet o
                    ON o.outlet_id = r.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = r.outlet_id

                WHERE r.room_id = ?
                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    roomId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (rooms.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Room not found'
            });
        }

        const room = rooms[0];

        // -------------------------------------------------
        // Room must be CLEANING
        // -------------------------------------------------

        if (room.status !== 'CLEANING') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Housekeeping cannot be started because room ${room.room_no} is ${room.status}`
            });
        }

        // -------------------------------------------------
        // Housekeeping must be DIRTY
        // -------------------------------------------------

        if (room.housekeeping_status !== 'DIRTY') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Housekeeping cannot be started for room ${room.room_no} because housekeeping status is ${room.housekeeping_status}`
            });
        }

        // -------------------------------------------------
        // Create housekeeping log
        // -------------------------------------------------

        const [logResult] =
            await connection.query(
                `
                INSERT INTO hotel_housekeeping_log
                (
                    outlet_id,
                    room_id,
                    status,
                    started_at,
                    started_by
                )
                VALUES
                (
                    ?,
                    ?,
                    'STARTED',
                    NOW(),
                    ?
                )
                `,
                [
                    room.outlet_id,
                    roomId,
                    req.user.userId
                ]
            );

        // -------------------------------------------------
        // Update room housekeeping status
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_room
            SET
                housekeeping_status = 'IN_PROGRESS',
                updated_by = ?,
                updated_at = NOW()
            WHERE room_id = ?
              AND outlet_id = ?
            `,
            [
                req.user.userId,
                roomId,
                room.outlet_id
            ]
        );

        await connection.commit();

        return res.json({

            success: true,

            message:
                'Housekeeping started',

            room: {
                roomId: room.room_id,
                roomNo: room.room_no,
                status: 'CLEANING',
                housekeepingStatus: 'IN_PROGRESS'
            },

            housekeeping: {
                housekeepingLogId:
                    logResult.insertId,

                status: 'STARTED'
            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Housekeeping start error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to start housekeeping'
        });

    } finally {

        connection.release();

    }
};

// =========================================================
// HOUSEKEEPING COMPLETE
//
// POST /hotel/rooms/:roomId/housekeeping-complete
// =========================================================

// =========================================================
// HOUSEKEEPING COMPLETE
//
// POST /hotel/rooms/:roomId/housekeeping-complete
// =========================================================

exports.housekeepingComplete = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const roomId =
            Number(req.params.roomId);

        if (!roomId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid roomId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Lock room + verify authorization
        // -------------------------------------------------

        const [rooms] =
            await connection.query(
                `
                SELECT
                    r.room_id,
                    r.outlet_id,
                    r.room_no,
                    r.status,
                    r.housekeeping_status

                FROM hotel_room r

                INNER JOIN outlet o
                    ON o.outlet_id = r.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = r.outlet_id

                WHERE r.room_id = ?
                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    roomId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (rooms.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Room not found'
            });
        }

        const room = rooms[0];

        // -------------------------------------------------
        // Room must be CLEANING
        // -------------------------------------------------

        if (room.status !== 'CLEANING') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Housekeeping cannot be completed because room ${room.room_no} is ${room.status}`
            });
        }

        // -------------------------------------------------
        // Housekeeping must be IN_PROGRESS
        // -------------------------------------------------

        if (room.housekeeping_status !== 'IN_PROGRESS') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Housekeeping cannot be completed for room ${room.room_no} because housekeeping status is ${room.housekeeping_status}`
            });
        }

        // -------------------------------------------------
        // Find active housekeeping log
        // -------------------------------------------------

        const [logs] =
            await connection.query(
                `
                SELECT
                    housekeeping_log_id,
                    started_at,
                    started_by

                FROM hotel_housekeeping_log

                WHERE room_id = ?
                  AND status = 'STARTED'

                ORDER BY housekeeping_log_id DESC

                LIMIT 1

                FOR UPDATE
                `,
                [
                    roomId
                ]
            );

        if (logs.length === 0) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'No active housekeeping session found for this room'
            });
        }

        const log = logs[0];

        // -------------------------------------------------
        // Calculate duration
        // -------------------------------------------------

        const [durationRows] =
            await connection.query(
                `
                SELECT
                    TIMESTAMPDIFF(
                        MINUTE,
                        started_at,
                        NOW()
                    ) AS duration_minutes

                FROM hotel_housekeeping_log

                WHERE housekeeping_log_id = ?
                `,
                [
                    log.housekeeping_log_id
                ]
            );

        const durationMinutes =
            durationRows[0]?.duration_minutes ?? 0;

        // -------------------------------------------------
        // Complete housekeeping log
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_housekeeping_log

            SET
                status = 'COMPLETED',
                completed_at = NOW(),
                duration_minutes = ?,
                completed_by = ?

            WHERE housekeeping_log_id = ?
            `,
            [
                durationMinutes,
                req.user.userId,
                log.housekeeping_log_id
            ]
        );

        // -------------------------------------------------
        // Make room available and clean
        // -------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_room

            SET
                status = 'AVAILABLE',
                housekeeping_status = 'CLEAN',
                updated_by = ?,
                updated_at = NOW()

            WHERE room_id = ?
              AND outlet_id = ?
            `,
            [
                req.user.userId,
                roomId,
                room.outlet_id
            ]
        );

        await connection.commit();

        return res.json({

            success: true,

            message:
                'Housekeeping completed successfully',

            room: {
                roomId: room.room_id,
                roomNo: room.room_no,
                status: 'AVAILABLE',
                housekeepingStatus: 'CLEAN'
            },

            housekeeping: {
                housekeepingLogId:
                    log.housekeeping_log_id,

                status: 'COMPLETED',

                startedAt:
                    log.started_at,

                completedAt:
                    new Date(),

                durationMinutes:
                    durationMinutes
            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Housekeeping complete error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to complete housekeeping'
        });

    } finally {

        connection.release();

    }
};
// =========================================================
// CREATE OR GET HOTEL FOLIO
//
// POST /hotel/stays/:stayId/folio
// =========================================================

exports.createOrGetFolio = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        if (!stayId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Get authorized stay
        // -------------------------------------------------

        const [stays] =
            await connection.query(
                `
                SELECT
                    hs.stay_id,
                    hs.outlet_id,
                    hs.guest_id,
                    hs.room_id,
                    hs.status,
                    hs.stay_no,

                    hg.first_name,
                    hg.last_name,

                    r.room_no

                FROM hotel_stay hs

                INNER JOIN outlet o
                    ON o.outlet_id = hs.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hs.outlet_id

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hs.guest_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                WHERE hs.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (stays.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Stay not found'
            });
        }

        const stay = stays[0];

        // -------------------------------------------------
        // Check existing folio
        // -------------------------------------------------

        const [folios] =
            await connection.query(
                `
                SELECT
                    *

                FROM hotel_folio

                WHERE stay_id = ?

                LIMIT 1

                FOR UPDATE
                `,
                [
                    stayId
                ]
            );

        let folio;

        // -------------------------------------------------
        // Existing folio
        // -------------------------------------------------

        if (folios.length > 0) {

            folio = folios[0];

        } else {

            // ---------------------------------------------
            // Generate folio number
            // ---------------------------------------------

            const folioNo =
                await generateFolioNo(
                    connection,
                    stay.outlet_id
                );

            // ---------------------------------------------
            // Create folio
            // ---------------------------------------------

            const [result] =
                await connection.query(
                    `
                    INSERT INTO hotel_folio
                    (
                        outlet_id,
                        stay_id,
                        folio_no,
                        status,
                        total_amount,
                        paid_amount,
                        balance_amount,
                        created_by,
                        updated_by
                    )
                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        'OPEN',
                        0.00,
                        0.00,
                        0.00,
                        ?,
                        ?
                    )
                    `,
                    [
                        stay.outlet_id,
                        stayId,
                        folioNo,
                        req.user.userId,
                        req.user.userId
                    ]
                );

            const folioId =
                result.insertId;

            folio = {
                folio_id: folioId,
                outlet_id: stay.outlet_id,
                stay_id: stayId,
                folio_no: folioNo,
                status: 'OPEN',
                total_amount: 0,
                paid_amount: 0,
                balance_amount: 0
            };
        }

        await connection.commit();

        return res.json({

            success: true,

            folio: {

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                stayId:
                    folio.stay_id,

                stayNo:
                    stay.stay_no,

                guestId:
                    stay.guest_id,

                guestName:
                    `${stay.first_name || ''} ${stay.last_name || ''}`
                        .trim(),

                roomId:
                    stay.room_id,

                roomNo:
                    stay.room_no,

                status:
                    folio.status,

                totalAmount:
                    Number(folio.total_amount || 0),

                paidAmount:
                    Number(folio.paid_amount || 0),

                balanceAmount:
                    Number(folio.balance_amount || 0)

            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Create/get folio error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to create/get hotel folio'
        });

    } finally {

        connection.release();
    }
};

// =========================================================
// GENERATE FOLIO NUMBER
// =========================================================

async function generateFolioNo(
    connection,
    outletId
) {

    const [rows] =
        await connection.query(
            `
            SELECT
                sequence_id,
                last_number

            FROM hotel_document_sequence

            WHERE outlet_id = ?
              AND document_type = 'FOLIO'

            FOR UPDATE
            `,
            [
                outletId
            ]
        );

    if (rows.length === 0) {

        await connection.query(
            `
            INSERT INTO hotel_document_sequence
            (
                outlet_id,
                document_type,
                last_number
            )
            VALUES
            (
                ?,
                'FOLIO',
                1
            )
            `,
            [
                outletId
            ]
        );

        return 'FOLIO-000001';
    }

    const nextNumber =
        Number(rows[0].last_number) + 1;

    await connection.query(
        `
        UPDATE hotel_document_sequence

        SET last_number = ?

        WHERE sequence_id = ?
        `,
        [
            nextNumber,
            rows[0].sequence_id
        ]
    );

    return `FOLIO-${String(nextNumber).padStart(6, '0')}`;
}


// =========================================================
// APPLY TAXES TO FOLIO ENTRY
// =========================================================

async function applyFolioEntryTaxes(
    connection,
    folioEntryId,
    taxableAmount,
    taxGroupId
) {

    const amount =
        Number(taxableAmount || 0);

    const groupId =
        taxGroupId
            ? Number(taxGroupId)
            : null;

    // No tax group or zero amount = no tax
    if (!groupId || amount <= 0) {
        return {
            taxAmount: 0,
            taxRows: []
        };
    }

    // -----------------------------------------------------
    // Get active tax rates
    // -----------------------------------------------------

    const [taxRates] =
        await connection.query(
            `
            SELECT
                tax_rate_id,
                tax_group_id,
                tax_name,
                tax_type,
                rate,
                is_inclusive

            FROM tax_rate

            WHERE tax_group_id = ?
              AND is_active = TRUE

            ORDER BY tax_rate_id
            `,
            [
                groupId
            ]
        );

    if (taxRates.length === 0) {
        return {
            taxAmount: 0,
            taxRows: []
        };
    }

    const normalizedRates =
        taxRates.map(rate => ({
            ...rate,

            rate:
                Number(rate.rate || 0),

            is_inclusive:
                Number(rate.is_inclusive || 0)
        }));

    // -----------------------------------------------------
    // Separate inclusive / exclusive taxes
    // -----------------------------------------------------

    const inclusiveRates =
        normalizedRates.filter(
            taxRate =>
                taxRate.is_inclusive === 1
        );

    const exclusiveRates =
        normalizedRates.filter(
            taxRate =>
                taxRate.is_inclusive === 0
        );

    const taxRows = [];

    let totalTaxAmount = 0;

    // -----------------------------------------------------
    // Inclusive-tax taxable base
    //
    // Example:
    //
    // Gross = 105
    // GST   = 5%
    //
    // Taxable = 105 / 1.05 = 100
    // Tax     = 5
    // -----------------------------------------------------

    let inclusiveTaxableAmount =
        amount;

    if (inclusiveRates.length > 0) {

        const totalInclusiveRate =
            inclusiveRates.reduce(
                (sum, taxRate) =>
                    sum + taxRate.rate,
                0
            );

        if (totalInclusiveRate > 0) {

            inclusiveTaxableAmount =
                amount /
                (
                    1 +
                    totalInclusiveRate / 100
                );

            inclusiveTaxableAmount =
                Math.round(
                    inclusiveTaxableAmount * 100
                ) / 100;
        }
    }

    // -----------------------------------------------------
    // Process inclusive taxes
    // -----------------------------------------------------

    for (const taxRate of inclusiveRates) {

        if (taxRate.rate <= 0) {
            continue;
        }

        const taxAmount =
            Math.round(
                (
                    inclusiveTaxableAmount *
                    taxRate.rate / 100
                ) * 100
            ) / 100;

        if (taxAmount <= 0) {
            continue;
        }

        await connection.query(
            `
            INSERT INTO hotel_folio_entry_tax
            (
                folio_entry_id,
                tax_group_id,
                tax_rate_id,
                tax_name,
                tax_type,
                rate,
                taxable_amount,
                tax_amount
            )
            VALUES
            (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?
            )
            `,
            [
                folioEntryId,
                taxRate.tax_group_id,
                taxRate.tax_rate_id,
                taxRate.tax_name,
                taxRate.tax_type,
                taxRate.rate,
                inclusiveTaxableAmount,
                taxAmount
            ]
        );

        taxRows.push({
            taxRateId:
                taxRate.tax_rate_id,

            taxName:
                taxRate.tax_name,

            taxType:
                taxRate.tax_type,

            rate:
                taxRate.rate,

            taxableAmount:
                inclusiveTaxableAmount,

            taxAmount
        });

        totalTaxAmount +=
            taxAmount;
    }

    // -----------------------------------------------------
    // Process exclusive taxes
    // -----------------------------------------------------

    for (const taxRate of exclusiveRates) {

        if (taxRate.rate <= 0) {
            continue;
        }

        const exclusiveTaxableAmount =
            amount;

        const taxAmount =
            Math.round(
                (
                    exclusiveTaxableAmount *
                    taxRate.rate / 100
                ) * 100
            ) / 100;

        if (taxAmount <= 0) {
            continue;
        }

        await connection.query(
            `
            INSERT INTO hotel_folio_entry_tax
            (
                folio_entry_id,
                tax_group_id,
                tax_rate_id,
                tax_name,
                tax_type,
                rate,
                taxable_amount,
                tax_amount
            )
            VALUES
            (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?
            )
            `,
            [
                folioEntryId,
                taxRate.tax_group_id,
                taxRate.tax_rate_id,
                taxRate.tax_name,
                taxRate.tax_type,
                taxRate.rate,
                exclusiveTaxableAmount,
                taxAmount
            ]
        );

        taxRows.push({
            taxRateId:
                taxRate.tax_rate_id,

            taxName:
                taxRate.tax_name,

            taxType:
                taxRate.tax_type,

            rate:
                taxRate.rate,

            taxableAmount:
                exclusiveTaxableAmount,

            taxAmount
        });

        totalTaxAmount +=
            taxAmount;
    }

    totalTaxAmount =
        Math.round(
            totalTaxAmount * 100
        ) / 100;

    return {
        taxAmount: totalTaxAmount,
        taxRows
    };
}


// =========================================================
// RECALCULATE HOTEL FOLIO
// =========================================================




async function recalculateFolio(
    connection,
    folioId,
    userId
) {

    // -----------------------------------------------------
    // 1. Lock folio
    // -----------------------------------------------------

    const [folios] =
        await connection.query(
            `
            SELECT
                folio_id,
                paid_amount,
                status

            FROM hotel_folio

            WHERE folio_id = ?

            FOR UPDATE
            `,
            [
                folioId
            ]
        );

    if (folios.length === 0) {
        throw new Error(
            'Hotel folio not found'
        );
    }

    // -----------------------------------------------------
    // 2. Calculate posted folio-entry amount
    // -----------------------------------------------------

    const [entryTotals] =
        await connection.query(
            `
            SELECT
                COALESCE(
                    SUM(
                        CASE
                            WHEN status = 'POSTED'
                            THEN amount
                            ELSE 0
                        END
                    ),
                    0
                ) AS entry_amount

            FROM hotel_folio_entry

            WHERE folio_id = ?
            `,
            [
                folioId
            ]
        );

    // -----------------------------------------------------
    // 3. Calculate posted tax amount
    //
    // Tax is included only when the parent folio entry
    // itself is POSTED.
    // -----------------------------------------------------

    const [taxTotals] =
        await connection.query(
            `
            SELECT
                COALESCE(
                    SUM(
                        CASE
                            WHEN hfe.status = 'POSTED'
                            THEN hfet.tax_amount
                            ELSE 0
                        END
                    ),
                    0
                ) AS tax_amount

            FROM hotel_folio_entry_tax hfet

            INNER JOIN hotel_folio_entry hfe
                ON hfe.folio_entry_id =
                   hfet.folio_entry_id

            WHERE hfe.folio_id = ?
            `,
            [
                folioId
            ]
        );

    const entryAmount =
        Number(
            entryTotals[0].entry_amount || 0
        );

    const taxAmount =
        Number(
            taxTotals[0].tax_amount || 0
        );

    // -----------------------------------------------------
    // 4. Calculate final folio total
    // -----------------------------------------------------

    const totalAmount =
        Math.round(
            (entryAmount + taxAmount) * 100
        ) / 100;

    // -----------------------------------------------------
    // 5. Recalculate successful payments
    // -----------------------------------------------------

    const [paymentTotals] =
        await connection.query(
            `
            SELECT
                COALESCE(
                    SUM(amount),
                    0
                ) AS paid_amount

            FROM hotel_folio_payment

            WHERE folio_id = ?
              AND status = 'SUCCESS'
            `,
            [
                folioId
            ]
        );

    const paidAmount =
        Number(
            paymentTotals[0].paid_amount || 0
        );

    // -----------------------------------------------------
    // 6. Calculate balance
    // -----------------------------------------------------

    const balanceAmount =
        Math.round(
            (totalAmount - paidAmount) * 100
        ) / 100;

    // -----------------------------------------------------
    // 7. Update folio
    // -----------------------------------------------------

    await connection.query(
        `
        UPDATE hotel_folio

        SET
            total_amount = ?,
            paid_amount = ?,
            balance_amount = ?,
            updated_by = ?

        WHERE folio_id = ?
        `,
        [
            totalAmount,
            paidAmount,
            Math.max(0, balanceAmount),
            userId,
            folioId
        ]
    );

    return {
        entryAmount,
        totalAmount,
        taxAmount,
        paidAmount,
        balanceAmount:
            Math.max(0, balanceAmount)
    };
}
// =========================================================
// GET HOTEL STAY FOLIO
//
// GET /hotel/stays/:stayId/folio
// =========================================================

exports.getStayFolio = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        if (!stayId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        // -------------------------------------------------
        // Get stay + folio
        // -------------------------------------------------

        const [folios] =
            await connection.query(
                `
                SELECT
                    hf.*,

                    hs.stay_no,
                    hs.guest_id,
                    hs.room_id,
                    hs.check_in,
                    hs.expected_check_out,
                    hs.status AS stay_status,

                    hg.guest_code,
                    hg.first_name,
                    hg.last_name,
                    hg.phone,

                    r.room_no,
                    r.room_name

                FROM hotel_folio hf

                INNER JOIN hotel_stay hs
                    ON hs.stay_id = hf.stay_id

                INNER JOIN outlet o
                    ON o.outlet_id = hf.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hf.outlet_id

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hs.guest_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                WHERE hf.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (folios.length === 0) {

            return res.status(404).json({
                success: false,
                message:
                    'Hotel folio not found'
            });
        }

        const folio = folios[0];



        // -------------------------------------------------
// Get folio payments
// -------------------------------------------------

        const [payments] =
            await connection.query(
                `
                SELECT
                    hfp.payment_id,
                    hfp.folio_id,
                    hfp.stay_id,
                    hfp.outlet_id,
                    hfp.payment_method,
                    hfp.amount,
                    hfp.reference_no,
                    hfp.remarks,
                    hfp.status,
                    hfp.created_at

                FROM hotel_folio_payment hfp

                WHERE hfp.folio_id = ?

                ORDER BY
                    hfp.payment_id
                `,
            [
                folio.folio_id
            ]
        );
        // -------------------------------------------------
        // Get ledger entries
        // -------------------------------------------------

        const [entries] =
            await connection.query(
                `
                SELECT
                    hfe.*

                FROM hotel_folio_entry hfe

                WHERE hfe.folio_id = ?

                ORDER BY
                    hfe.entry_date,
                    hfe.folio_entry_id
                `,
                [
                    folio.folio_id
                ]
            );


        // -------------------------------------------------
        // Calculate monetary summary
        // -------------------------------------------------

        const [entryTotals] =
            await connection.query(
                `
                SELECT
                    COALESCE(
                        SUM(
                            CASE
                                WHEN status = 'POSTED'
                                THEN amount
                                ELSE 0
                            END
                        ),
                        0
                    ) AS entry_amount
            
                FROM hotel_folio_entry
            
                WHERE folio_id = ?
                `,
                [
                    folio.folio_id
                ]
            );
        
        const [taxTotals] =
            await connection.query(
                `
                SELECT
                    COALESCE(
                        SUM(
                            CASE
                                WHEN hfe.status = 'POSTED'
                                THEN hfet.tax_amount
                                ELSE 0
                            END
                        ),
                        0
                    ) AS tax_amount
            
                FROM hotel_folio_entry_tax hfet
            
                INNER JOIN hotel_folio_entry hfe
                    ON hfe.folio_entry_id =
                       hfet.folio_entry_id
            
                WHERE hfe.folio_id = ?
                `,
                [
                    folio.folio_id
                ]
            );
        
        const entryAmount =
            Number(
                entryTotals[0].entry_amount || 0
            );
        
        const taxAmount =
            Number(
                taxTotals[0].tax_amount || 0
            );
        
        const totalAmount =
            Math.round(
                (entryAmount + taxAmount) * 100
            ) / 100;
        
        const paidAmount =
            Number(
                folio.paid_amount || 0
            );
        
        const balanceAmount =
            Math.max(
                0,
                Math.round(
                    (totalAmount - paidAmount) * 100
                ) / 100
            );

        // -------------------------------------------------
        // Get tax details for folio entries
        // -------------------------------------------------

        const [entryTaxes] =
            await connection.query(
                `
                SELECT
                    hfet.folio_entry_tax_id,
                    hfet.folio_entry_id,
                    hfet.tax_group_id,
                    hfet.tax_rate_id,
                    hfet.tax_name,
                    hfet.tax_type,
                    hfet.rate,
                    hfet.taxable_amount,
                    hfet.tax_amount
            
                FROM hotel_folio_entry_tax hfet
            
                INNER JOIN hotel_folio_entry hfe
                    ON hfe.folio_entry_id =
                       hfet.folio_entry_id
            
                WHERE hfe.folio_id = ?
                  AND hfe.status = 'POSTED'
            
                ORDER BY
                    hfet.folio_entry_id,
                    hfet.tax_rate_id
                `,
                [
                    folio.folio_id
                ]
            );

        const taxMap = new Map();

        for (const tax of entryTaxes) {
        
            const entryId =
                Number(tax.folio_entry_id);
        
            if (!taxMap.has(entryId)) {
                taxMap.set(entryId, []);
            }
        
            taxMap.get(entryId).push({
                folioEntryTaxId:
                    tax.folio_entry_tax_id,
            
                taxGroupId:
                    tax.tax_group_id,
            
                taxRateId:
                    tax.tax_rate_id,
            
                taxName:
                    tax.tax_name,
            
                taxType:
                    tax.tax_type,
            
                rate:
                    Number(tax.rate || 0),
            
                taxableAmount:
                    Number(
                        tax.taxable_amount || 0
                    ),
                
                taxAmount:
                    Number(
                        tax.tax_amount || 0
                    )
            });
        }    

        
        return res.json({

            success: true,

            folio: {

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                stayId:
                    folio.stay_id,

                stayNo:
                    folio.stay_no,

                stayStatus:
                    folio.stay_status,

                guest: {

                    guestId:
                        folio.guest_id,

                    guestCode:
                        folio.guest_code,

                    firstName:
                        folio.first_name,

                    lastName:
                        folio.last_name,

                    phone:
                        folio.phone

                },

                room: {

                    roomId:
                        folio.room_id,

                    roomNo:
                        folio.room_no,

                    roomName:
                        folio.room_name

                },

                checkIn:
                    folio.check_in,

                expectedCheckOut:
                    folio.expected_check_out,

                status:
                    folio.status,

                monetary: 
                        {

                            entryAmount,

                            taxAmount,

                            totalAmount,

                            paidAmount,

                            balanceAmount
                        },

                entries:
                    entries.map(entry => ({

                        folioEntryId:
                            entry.folio_entry_id,

                        entryDate:
                            entry.entry_date,

                        entryType:
                            entry.entry_type,

                        description:
                            entry.description,

                        quantity:
                            Number(
                                entry.quantity || 0
                            ),

                        rate:
                            Number(
                                entry.rate || 0
                            ),

                        amount:
                            Number(
                                entry.amount || 0
                            ),
                        taxes:
                            taxMap.get(
                                Number(entry.folio_entry_id)
                            ) || [],        
                        sourceType:
                            entry.source_type,

                        sourceId:
                            entry.source_id,

                        referenceEntryId:
                            entry.reference_entry_id,

                        status:
                            entry.status,

                        remarks:
                            entry.remarks

                    })),

                payments:
    payments.map(payment => ({

        paymentId:
            payment.payment_id,

        folioId:
            payment.folio_id,

        stayId:
            payment.stay_id,

        outletId:
            payment.outlet_id,

        paymentMethod:
            payment.payment_method,

        amount:
            Number(
                payment.amount || 0
            ),

        referenceNo:
            payment.reference_no,

        remarks:
            payment.remarks,

        status:
            payment.status,

        createdAt:
            payment.created_at

    }))        






                    
            }

        });

    } catch (error) {

        console.error(
            'Get stay folio error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get hotel folio'
        });

    } finally {

        connection.release();
    }
};


// =========================================================
// RECALCULATE HOTEL FOLIO
// =========================================================


// =========================================================
// CHARGE RESTAURANT BILL TO HOTEL FOLIO
//
// POST /hotel/folio/charge-restaurant-bill
//
// Body:
// {
//     "billId": 12,
//     "stayId": 1
// }
// =========================================================

exports.chargeRestaurantBill = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const billId = Number(req.body.billId);
        const stayId = Number(req.body.stayId);

        if (!billId || !stayId) {

            return res.status(400).json({
                success: false,
                message: 'billId and stayId are required'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // 1. Get and lock the stay
        // -------------------------------------------------

        const [stays] = await connection.query(
            `
            SELECT
                hs.stay_id,
                hs.outlet_id,
                hs.guest_id,
                hs.room_id,
                hs.stay_no,
                hs.status,

                hg.first_name,
                hg.last_name,

                r.room_no

            FROM hotel_stay hs

            INNER JOIN outlet o
                ON o.outlet_id = hs.outlet_id

            INNER JOIN user_outlet uo
                ON uo.outlet_id = hs.outlet_id

            INNER JOIN hotel_guest hg
                ON hg.guest_id = hs.guest_id

            INNER JOIN hotel_room r
                ON r.room_id = hs.room_id

            WHERE hs.stay_id = ?
              AND o.company_id = ?
              AND uo.user_id = ?

            FOR UPDATE
            `,
            [
                stayId,
                req.user.companyId,
                req.user.userId
            ]
        );

        if (stays.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Hotel stay not found'
            });
        }

        const stay = stays[0];

        // Restaurant charges should only be posted
        // while the guest is checked in.

        if (stay.status !== 'CHECKED_IN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Restaurant bill can only be charged to a CHECKED_IN stay. Current status: ${stay.status}`
            });
        }

        // -------------------------------------------------
        // 2. Get and lock restaurant bill
        // -------------------------------------------------

        const [bills] = await connection.query(
            `
            SELECT
                b.*,
                o.order_id,
                o.order_no,
                o.table_id,
                o.hotel_stay_id,
                o.hotel_room_id
            FROM bill b

            INNER JOIN orders o
                ON o.order_id = b.order_id

            WHERE b.bill_id = ?

            FOR UPDATE
            `,
            [
                billId
            ]
        );

        if (bills.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Restaurant bill not found'
            });
        }

        const bill = bills[0];

        // -------------------------------------------------
        // 3. Verify same outlet
        // -------------------------------------------------

        if (Number(bill.outlet_id) !== Number(stay.outlet_id)) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Restaurant bill and hotel stay belong to different outlets'
            });
        }

        // -------------------------------------------------
        // 4. Validate bill status
        // -------------------------------------------------

        if (
            bill.bill_status === 'CANCELLED' ||
            bill.bill_status === 'VOID' ||
            bill.bill_status === 'REFUNDED'
        ) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Restaurant bill cannot be charged. Bill status: ${bill.bill_status}`
            });
        }

        // -------------------------------------------------
        // 5. Check whether already charged
        // -------------------------------------------------

        const [existingCharges] =
            await connection.query(
                `
                SELECT
                    folio_entry_id,
                    folio_id,
                    status

                FROM hotel_folio_entry

                WHERE source_type = 'RESTAURANT_BILL'
                  AND source_id = ?

                FOR UPDATE
                `,
                [
                    billId
                ]
            );

        if (existingCharges.length > 0) {

            const existing =
                existingCharges[0];

            await connection.rollback();

            return res.status(409).json({
                success: false,
                message:
                    'Restaurant bill has already been charged to a hotel folio',
                folioEntryId:
                    existing.folio_entry_id,
                folioId:
                    existing.folio_id,
                status:
                    existing.status
            });
        }

        // -------------------------------------------------
        // 6. Get or create folio
        // -------------------------------------------------

        const [folios] =
            await connection.query(
                `
                SELECT *
                FROM hotel_folio

                WHERE stay_id = ?

                LIMIT 1

                FOR UPDATE
                `,
                [
                    stayId
                ]
            );

        let folio;

        if (folios.length > 0) {

            folio = folios[0];

        } else {

            const folioNo =
                await generateFolioNo(
                    connection,
                    stay.outlet_id
                );

            const [folioResult] =
                await connection.query(
                    `
                    INSERT INTO hotel_folio
                    (
                        outlet_id,
                        stay_id,
                        folio_no,
                        status,
                        total_amount,
                        paid_amount,
                        balance_amount,
                        created_by,
                        updated_by
                    )
                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        'OPEN',
                        0.00,
                        0.00,
                        0.00,
                        ?,
                        ?
                    )
                    `,
                    [
                        stay.outlet_id,
                        stayId,
                        folioNo,
                        req.user.userId,
                        req.user.userId
                    ]
                );

            folio = {
                folio_id:
                    folioResult.insertId,

                outlet_id:
                    stay.outlet_id,

                stay_id:
                    stayId,

                folio_no:
                    folioNo,

                status:
                    'OPEN',

                total_amount: 0,
                paid_amount: 0,
                balance_amount: 0
            };
        }

        // -------------------------------------------------
        // 7. Make sure folio is open
        // -------------------------------------------------

        if (folio.status !== 'OPEN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Hotel folio is not open. Current status: ${folio.status}`
            });
        }

        // -------------------------------------------------
        // 8. Restaurant bill amount
        // -------------------------------------------------

        const billAmount = 
            Number(
                bill.grand_total ||
                0
            );

        if (billAmount <= 0) {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Restaurant bill amount must be greater than zero'
            });
        }

        // -------------------------------------------------
        // 9. Insert folio entry
        // -------------------------------------------------

        const description =
            `Restaurant Bill ${bill.bill_no || billId}`;

        const [entryResult] =
            await connection.query(
                `
                INSERT INTO hotel_folio_entry
                (
                    folio_id,
                    stay_id,
                    outlet_id,
                    entry_date,
                    entry_type,
                    description,
                    quantity,
                    rate,
                    amount,
                    source_type,
                    source_id,
                    status,
                    created_by
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    NOW(),
                    'RESTAURANT',
                    ?,
                    1,
                    ?,
                    ?,
                    'RESTAURANT_BILL',
                    ?,
                    'POSTED',
                    ?
                )
                `,
                [
                    folio.folio_id,
                    stayId,
                    stay.outlet_id,
                    description,
                    billAmount,
                    billAmount,
                    billId,
                    req.user.userId
                ]
            );

        const folioEntryId =
            entryResult.insertId;


            // -------------------------------------------------
            // 9A. Link restaurant bill to hotel stay / room
            // -------------------------------------------------

            await connection.query(
                `
                UPDATE bill
            
                SET
                    hotel_stay_id = ?,
                    hotel_room_id = ?,
                    updated_by = ?
            
                WHERE bill_id = ?
                `,
                [
                    stayId,
                    stay.room_id,
                    req.user.userId,
                    billId
                ]
            );


        // -------------------------------------------------
        // 10. Recalculate folio
        // -------------------------------------------------

        const folioTotals =
            await recalculateFolio(
                connection,
                folio.folio_id,
                req.user.userId
            );
        
        const totalAmount =
            folioTotals.totalAmount;
        
        const paidAmount =
            folioTotals.paidAmount;
        
        const balanceAmount =
            folioTotals.balanceAmount;


        await connection.commit();

        return res.json({

            success: true,

            message:
                'Restaurant bill charged to hotel folio successfully',

            charge: {

                folioEntryId,

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                stayId,

                stayNo:
                    stay.stay_no,

                guestName:
                    `${stay.first_name || ''} ${stay.last_name || ''}`
                        .trim(),

                roomNo:
                    stay.room_no,

                billId,

                billNo:
                    bill.bill_no,

                amount:
                    billAmount,

                totalAmount,

                paidAmount,

                balanceAmount

            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Charge restaurant bill error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to charge restaurant bill to hotel folio'
        });

    } finally {

        connection.release();
    }
};


// =========================================================
// CREATE OR GET HOTEL FOLIO
//
// POST /hotel/stays/:stayId/folio
// =========================================================

exports.createOrGetFolio = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        if (!stayId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // Get authorized stay
        // -------------------------------------------------

        const [stays] =
            await connection.query(
                `
                SELECT
                    hs.stay_id,
                    hs.outlet_id,
                    hs.guest_id,
                    hs.room_id,
                    hs.status,
                    hs.stay_no,

                    hg.first_name,
                    hg.last_name,

                    r.room_no

                FROM hotel_stay hs

                INNER JOIN outlet o
                    ON o.outlet_id = hs.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hs.outlet_id

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hs.guest_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                WHERE hs.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (stays.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Stay not found'
            });
        }

        const stay = stays[0];

        // -------------------------------------------------
        // Check existing folio
        // -------------------------------------------------

        const [folios] =
            await connection.query(
                `
                SELECT
                    *

                FROM hotel_folio

                WHERE stay_id = ?

                LIMIT 1

                FOR UPDATE
                `,
                [
                    stayId
                ]
            );

        let folio;

        // -------------------------------------------------
        // Existing folio
        // -------------------------------------------------

        if (folios.length > 0) {

            folio = folios[0];

        } else {

            // ---------------------------------------------
            // Generate folio number
            // ---------------------------------------------

            const folioNo =
                await generateFolioNo(
                    connection,
                    stay.outlet_id
                );

            // ---------------------------------------------
            // Create folio
            // ---------------------------------------------

            const [result] =
                await connection.query(
                    `
                    INSERT INTO hotel_folio
                    (
                        outlet_id,
                        stay_id,
                        folio_no,
                        status,
                        total_amount,
                        paid_amount,
                        balance_amount,
                        created_by,
                        updated_by
                    )
                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        'OPEN',
                        0.00,
                        0.00,
                        0.00,
                        ?,
                        ?
                    )
                    `,
                    [
                        stay.outlet_id,
                        stayId,
                        folioNo,
                        req.user.userId,
                        req.user.userId
                    ]
                );

            const folioId =
                result.insertId;

            folio = {
                folio_id: folioId,
                outlet_id: stay.outlet_id,
                stay_id: stayId,
                folio_no: folioNo,
                status: 'OPEN',
                total_amount: 0,
                paid_amount: 0,
                balance_amount: 0
            };
        }

        await connection.commit();

        return res.json({

            success: true,

            folio: {

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                stayId:
                    folio.stay_id,

                stayNo:
                    stay.stay_no,

                guestId:
                    stay.guest_id,

                guestName:
                    `${stay.first_name || ''} ${stay.last_name || ''}`
                        .trim(),

                roomId:
                    stay.room_id,

                roomNo:
                    stay.room_no,

                status:
                    folio.status,

                totalAmount:
                    Number(folio.total_amount || 0),

                paidAmount:
                    Number(folio.paid_amount || 0),

                balanceAmount:
                    Number(folio.balance_amount || 0)

            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Create/get folio error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to create/get hotel folio'
        });

    } finally {

        connection.release();
    }
};


// =========================================================
// GENERATE FOLIO NUMBER
// =========================================================

async function generateFolioNo(
    connection,
    outletId
) {

    const [rows] =
        await connection.query(
            `
            SELECT
                sequence_id,
                last_number

            FROM hotel_document_sequence

            WHERE outlet_id = ?
              AND document_type = 'FOLIO'

            FOR UPDATE
            `,
            [
                outletId
            ]
        );

    if (rows.length === 0) {

        await connection.query(
            `
            INSERT INTO hotel_document_sequence
            (
                outlet_id,
                document_type,
                last_number
            )
            VALUES
            (
                ?,
                'FOLIO',
                1
            )
            `,
            [
                outletId
            ]
        );

        return 'FOLIO-000001';
    }

    const nextNumber =
        Number(rows[0].last_number) + 1;

    await connection.query(
        `
        UPDATE hotel_document_sequence

        SET last_number = ?

        WHERE sequence_id = ?
        `,
        [
            nextNumber,
            rows[0].sequence_id
        ]
    );

    return `FOLIO-${String(nextNumber).padStart(6, '0')}`;
}

// =========================================================
// GET HOTEL STAY FOLIO
//
// GET /hotel/stays/:stayId/folio
// =========================================================
/*
exports.getStayFolio = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.params.stayId);

        if (!stayId) {

            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        // -------------------------------------------------
        // Get stay + folio
        // -------------------------------------------------

        const [folios] =
            await connection.query(
                `
                SELECT
                    hf.*,

                    hs.stay_no,
                    hs.guest_id,
                    hs.room_id,
                    hs.check_in,
                    hs.expected_check_out,
                    hs.status AS stay_status,

                    hg.guest_code,
                    hg.first_name,
                    hg.last_name,
                    hg.phone,

                    r.room_no,
                    r.room_name

                FROM hotel_folio hf

                INNER JOIN hotel_stay hs
                    ON hs.stay_id = hf.stay_id

                INNER JOIN outlet o
                    ON o.outlet_id = hf.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hf.outlet_id

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hs.guest_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                WHERE hf.stay_id = ?

                  AND o.company_id = ?
                  AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (folios.length === 0) {

            return res.status(404).json({
                success: false,
                message:
                    'Hotel folio not found'
            });
        }

        const folio = folios[0];

        // -------------------------------------------------
        // Get ledger entries
        // -------------------------------------------------

        const [entries] =
            await connection.query(
                `
                SELECT
                    hfe.*

                FROM hotel_folio_entry hfe

                WHERE hfe.folio_id = ?

                ORDER BY
                    hfe.entry_date,
                    hfe.folio_entry_id
                `,
                [
                    folio.folio_id
                ]
            );

        return res.json({

            success: true,

            folio: {

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                stayId:
                    folio.stay_id,

                stayNo:
                    folio.stay_no,

                stayStatus:
                    folio.stay_status,

                guest: {

                    guestId:
                        folio.guest_id,

                    guestCode:
                        folio.guest_code,

                    firstName:
                        folio.first_name,

                    lastName:
                        folio.last_name,

                    phone:
                        folio.phone

                },

                room: {

                    roomId:
                        folio.room_id,

                    roomNo:
                        folio.room_no,

                    roomName:
                        folio.room_name

                },

                checkIn:
                    folio.check_in,

                expectedCheckOut:
                    folio.expected_check_out,

                status:
                    folio.status,

                totalAmount:
                    Number(
                        folio.total_amount || 0
                    ),

                paidAmount:
                    Number(
                        folio.paid_amount || 0
                    ),

                balanceAmount:
                    Number(
                        folio.balance_amount || 0
                    ),

                entries:
                    entries.map(entry => ({

                        folioEntryId:
                            entry.folio_entry_id,

                        entryDate:
                            entry.entry_date,

                        entryType:
                            entry.entry_type,

                        description:
                            entry.description,

                        quantity:
                            Number(
                                entry.quantity || 0
                            ),

                        rate:
                            Number(
                                entry.rate || 0
                            ),

                        amount:
                            Number(
                                entry.amount || 0
                            ),

                        sourceType:
                            entry.source_type,

                        sourceId:
                            entry.source_id,

                        referenceEntryId:
                            entry.reference_entry_id,

                        status:
                            entry.status,

                        remarks:
                            entry.remarks

                    }))

            }

        });

    } catch (error) {

        console.error(
            'Get stay folio error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get hotel folio'
        });

    } finally {

        connection.release();
    }
};
*/

// =========================================================
// GET ACTIVE HOTEL STAYS
//
// GET /hotel/stays/active?outletId=1
//
// Returns currently CHECKED_IN guests/rooms.
// Used by Restaurant POS -> Charge to Room.
// =========================================================

exports.getActiveStays = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const outletId =
            Number(req.query.outletId);

        if (!outletId) {

            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        // -------------------------------------------------
        // Verify outlet belongs to user's company
        // and user has access to outlet
        // -------------------------------------------------

        const [outlets] =
            await connection.query(
                `
                SELECT
                    o.outlet_id,
                    o.outlet_name

                FROM outlet o

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = o.outlet_id

                WHERE o.outlet_id = ?
                  AND o.company_id = ?
                  AND uo.user_id = ?

                LIMIT 1
                `,
                [
                    outletId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (outlets.length === 0) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });
        }

        // -------------------------------------------------
        // Get currently checked-in stays
        // -------------------------------------------------

        const [stays] =
            await connection.query(
                `
                SELECT

                    hs.stay_id,
                    hs.outlet_id,
                    hs.guest_id,
                    hs.room_id,
                    hs.stay_no,

                    hs.check_in,
                    hs.expected_check_out,

                    hs.adults,
                    hs.children,

                    hs.room_rate,
                    hs.status,

                    hg.guest_code,
                    hg.first_name,
                    hg.last_name,
                    hg.phone,

                    r.room_no,
                    r.room_name,

                    rt.type_code,
                    rt.type_name

                FROM hotel_stay hs

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hs.guest_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                INNER JOIN room_type rt
                    ON rt.room_type_id = r.room_type_id

                WHERE hs.outlet_id = ?
                  AND hs.status = 'CHECKED_IN'

                ORDER BY
                    r.room_no,
                    hg.first_name,
                    hg.last_name
                `,
                [
                    outletId
                ]
            );

        // -------------------------------------------------
        // Return POS-friendly response
        // -------------------------------------------------

        return res.json({

            success: true,

            outlet: {
                outletId:
                    outletId,

                outletName:
                    outlets[0].outlet_name
            },

            count:
                stays.length,

            stays:
                stays.map(stay => ({

                    stayId:
                        stay.stay_id,

                    stayNo:
                        stay.stay_no,

                    guest: {

                        guestId:
                            stay.guest_id,

                        guestCode:
                            stay.guest_code,

                        firstName:
                            stay.first_name,

                        lastName:
                            stay.last_name,

                        phone:
                            stay.phone

                    },

                    room: {

                        roomId:
                            stay.room_id,

                        roomNo:
                            stay.room_no,

                        roomName:
                            stay.room_name,

                        roomTypeCode:
                            stay.type_code,

                        roomTypeName:
                            stay.type_name

                    },

                    checkIn:
                        stay.check_in,

                    expectedCheckOut:
                        stay.expected_check_out,

                    adults:
                        Number(stay.adults || 0),

                    children:
                        Number(stay.children || 0),

                    roomRate:
                        Number(stay.room_rate || 0),

                    status:
                        stay.status

                }))

        });

    } catch (error) {

        console.error(
            'Get active hotel stays error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get active hotel stays'
        });

    } finally {

        connection.release();
    }
};

// =========================================================
// ADD HOTEL FOLIO CHARGE
//
// POST /hotel/folio/add-charge
//
// Body:
// {
//     "stayId": 1,
//     "entryType": "LAUNDRY",
//     "description": "Laundry - 5 garments",
//     "quantity": 1,
//     "rate": 300,
//     "remarks": "Express laundry"
// }
// =========================================================

exports.addFolioCharge = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const stayId =
            Number(req.body.stayId);

        const entryType =
            String(req.body.entryType || '')
                .trim()
                .toUpperCase();

        const description =
            String(req.body.description || '')
                .trim();

        const quantity =
            Number(req.body.quantity ?? 1);

        const rate =
            Number(req.body.rate ?? 0);

        const remarks =
            req.body.remarks || null;

        const taxGroupId =
            req.body.taxGroupId
                ? Number(req.body.taxGroupId)
                : null;


        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        const allowedTypes = [
            'ROOM_CHARGE',
            'LAUNDRY',
            'MINIBAR',
            'SERVICE',
            'OTHER',
            'DISCOUNT',
            'ADJUSTMENT'
        ];

        if (!stayId) {

            return res.status(400).json({
                success: false,
                message: 'stayId is required'
            });
        }

        if (!allowedTypes.includes(entryType)) {

            return res.status(400).json({
                success: false,
                message:
                    `Invalid entryType. Allowed values: ${allowedTypes.join(', ')}`
            });
        }

        if (!description) {

            return res.status(400).json({
                success: false,
                message: 'description is required'
            });
        }

        if (quantity <= 0) {

            return res.status(400).json({
                success: false,
                message:
                    'quantity must be greater than zero'
            });
        }

        if (rate < 0) {

            return res.status(400).json({
                success: false,
                message:
                    'rate cannot be negative'
            });
        }

        // -------------------------------------------------
        // Discount cannot use positive amount.
        //
        // We store discounts as negative folio entries.
        // -------------------------------------------------

        let amount =
            quantity * rate;

        if (entryType === 'DISCOUNT') {
            amount = -Math.abs(amount);
        }

        if (entryType !== 'DISCOUNT' &&
            entryType !== 'ADJUSTMENT' &&
            amount <= 0) {

            return res.status(400).json({
                success: false,
                message:
                    'Charge amount must be greater than zero'
            });
        }

        if (
            taxGroupId !== null &&
            (!Number.isInteger(taxGroupId) || taxGroupId <= 0)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid taxGroupId'
            });
        }

        await connection.beginTransaction();

        // -------------------------------------------------
        // 1. Get and lock stay
        // -------------------------------------------------

        const [stays] =
            await connection.query(
                `
                SELECT
                    hs.stay_id,
                    hs.outlet_id,
                    hs.guest_id,
                    hs.room_id,
                    hs.stay_no,
                    hs.status,

                    hg.first_name,
                    hg.last_name,

                    r.room_no

                FROM hotel_stay hs

                INNER JOIN outlet o
                    ON o.outlet_id = hs.outlet_id

                INNER JOIN user_outlet uo
                    ON uo.outlet_id = hs.outlet_id

                INNER JOIN hotel_guest hg
                    ON hg.guest_id = hs.guest_id

                INNER JOIN hotel_room r
                    ON r.room_id = hs.room_id

                WHERE hs.stay_id = ?
                  AND o.company_id = ?
                  AND uo.user_id = ?

                FOR UPDATE
                `,
                [
                    stayId,
                    req.user.companyId,
                    req.user.userId
                ]
            );

        if (stays.length === 0) {

            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Hotel stay not found'
            });
        }

        const stay = stays[0];

        // -------------------------------------------------
        // 2. Only checked-in guests can receive charges
        // -------------------------------------------------

        if (stay.status !== 'CHECKED_IN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Charges can only be posted to a CHECKED_IN stay. Current status: ${stay.status}`
            });
        }

        // -------------------------------------------------
        // 3. Get or create folio
        // -------------------------------------------------

        const [folios] =
            await connection.query(
                `
                SELECT *
                FROM hotel_folio

                WHERE stay_id = ?

                LIMIT 1

                FOR UPDATE
                `,
                [
                    stayId
                ]
            );

        let folio;

        if (folios.length > 0) {

            folio = folios[0];

        } else {

            const folioNo =
                await generateFolioNo(
                    connection,
                    stay.outlet_id
                );

            const [result] =
                await connection.query(
                    `
                    INSERT INTO hotel_folio
                    (
                        outlet_id,
                        stay_id,
                        folio_no,
                        status,
                        total_amount,
                        paid_amount,
                        balance_amount,
                        created_by,
                        updated_by
                    )
                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        'OPEN',
                        0.00,
                        0.00,
                        0.00,
                        ?,
                        ?
                    )
                    `,
                    [
                        stay.outlet_id,
                        stayId,
                        folioNo,
                        req.user.userId,
                        req.user.userId
                    ]
                );

            folio = {
                folio_id: result.insertId,
                folio_no: folioNo,
                status: 'OPEN',
                total_amount: 0,
                paid_amount: 0,
                balance_amount: 0
            };
        }

        // -------------------------------------------------
        // 4. Folio must be open
        // -------------------------------------------------

        if (folio.status !== 'OPEN') {

            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Hotel folio is not open. Current status: ${folio.status}`
            });
        }

        // -------------------------------------------------
        // 5. Insert folio entry
        // -------------------------------------------------

        const [entryResult] =
            await connection.query(
                `
                INSERT INTO hotel_folio_entry
                (
                    folio_id,
                    stay_id,
                    outlet_id,
                    entry_date,
                    entry_type,
                    description,
                    quantity,
                    rate,
                    amount,
                    source_type,
                    source_id,
                    status,
                    remarks,
                    created_by
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    NOW(),
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    NULL,
                    NULL,
                    'POSTED',
                    ?,
                    ?
                )
                `,
                [
                    folio.folio_id,
                    stayId,
                    stay.outlet_id,
                    entryType,
                    description,
                    quantity,
                    rate,
                    amount,
                    remarks,
                    req.user.userId
                ]
            );

        const folioEntryId =
            entryResult.insertId;


        // -------------------------------------------------
        // 6A. Apply taxes
        // -------------------------------------------------

        const taxResult =
            await applyFolioEntryTaxes(
                connection,
                folioEntryId,
                amount > 0 ? amount : 0,
                taxGroupId
            );
        
        const totalTaxAmount =
            taxResult.taxAmount;
                // -------------------------------------------------
        
       // -------------------------------------------------
        // 6. Recalculate folio
        // -------------------------------------------------

        const folioTotals =
            await recalculateFolio(
                connection,
                folio.folio_id,
                req.user.userId
            );
        
        const totalAmount =
            folioTotals.totalAmount;
        
        const paidAmount =
            folioTotals.paidAmount;
        
        const balanceAmount =
            folioTotals.balanceAmount;

      

        await connection.commit();

        return res.json({

            success: true,

            message:
                'Folio charge added successfully',

            charge: {

                folioEntryId,

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                stayId,

                stayNo:
                    stay.stay_no,

                guestName:
                    `${stay.first_name || ''} ${stay.last_name || ''}`
                        .trim(),

                roomNo:
                    stay.room_no,

                entryType,

                description,

                quantity,

                rate,

                amount,

                totalAmount,

                paidAmount,

                balanceAmount

            }

        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Add folio charge error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to add folio charge'
        });

    } finally {

        connection.release();
    }
};


exports.addFolioPayment = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const userId = req.user.userId;
        const companyId = req.user.companyId;

        const {
            folioId,
            stayId,
            paymentMethod,
            amount,
            referenceNo,
            remarks
        } = req.body;

        // --------------------------------------------------
        // 1. Basic validation
        // --------------------------------------------------

        if (!folioId || !stayId) {
            return res.status(400).json({
                success: false,
                message: 'folioId and stayId are required'
            });
        }

        const paymentAmount = Number(amount);

        if (!Number.isFinite(paymentAmount) || paymentAmount <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Payment amount must be greater than zero'
            });
        }

        const allowedMethods = [
            'CASH',
            'CARD',
            'UPI',
            'BANK',
            'OTHER'
        ];

        if (!allowedMethods.includes(paymentMethod)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid payment method'
            });
        }

        await connection.beginTransaction();

        // --------------------------------------------------
        // 2. Validate user outlet access
        // --------------------------------------------------

        const [outlets] = await connection.query(
            `
            SELECT o.outlet_id
            FROM outlet o
            INNER JOIN user_outlet uo
                ON uo.outlet_id = o.outlet_id
            WHERE o.company_id = ?
              AND uo.user_id = ?
            `,
            [companyId, userId]
        );

        if (!outlets.length) {
            await connection.rollback();

            return res.status(403).json({
                success: false,
                message: 'User has no outlet access'
            });
        }

        const outletId = outlets[0].outlet_id;

        // --------------------------------------------------
        // 3. Lock folio
        // --------------------------------------------------

        const [folios] = await connection.query(
            `
            SELECT *
            FROM hotel_folio
            WHERE folio_id = ?
              AND stay_id = ?
              AND outlet_id = ?
            FOR UPDATE
            `,
            [folioId, stayId, outletId]
        );

        if (!folios.length) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Folio not found'
            });
        }

        const folio = folios[0];

        // --------------------------------------------------
        // 4. Folio must be open
        // --------------------------------------------------

        if (folio.status !== 'OPEN') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: `Folio is ${folio.status}`
            });
        }

        // --------------------------------------------------
        // 5. Lock stay
        // --------------------------------------------------

        const [stays] = await connection.query(
            `
            SELECT *
            FROM hotel_stay
            WHERE stay_id = ?
              AND outlet_id = ?
            FOR UPDATE
            `,
            [stayId, outletId]
        );

        if (!stays.length) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Hotel stay not found'
            });
        }

        const stay = stays[0];

        if (stay.status !== 'CHECKED_IN') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: `Guest stay is ${stay.status}`
            });
        }

        // --------------------------------------------------
        // 6. Calculate actual paid amount
        // --------------------------------------------------

        const [paymentTotals] = await connection.query(
            `
            SELECT
                COALESCE(SUM(amount), 0) AS paid_amount
            FROM hotel_folio_payment
            WHERE folio_id = ?
              AND status = 'SUCCESS'
            `,
            [folioId]
        );

        const paidAmount = Number(
            paymentTotals[0].paid_amount || 0
        );

        var totalAmount = Number(
            folio.total_amount || 0
        );

        const balanceAmount = totalAmount - paidAmount;

        // --------------------------------------------------
        // 7. Prevent overpayment
        // --------------------------------------------------

        if (paymentAmount > balanceAmount + 0.01) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'Payment amount exceeds outstanding balance',
                totalAmount,
                paidAmount,
                balanceAmount
            });
        }

        // --------------------------------------------------
        // 8. Insert payment
        // --------------------------------------------------

        const [paymentResult] = await connection.query(
            `
            INSERT INTO hotel_folio_payment
            (
                folio_id,
                stay_id,
                outlet_id,
                payment_method,
                amount,
                reference_no,
                remarks,
                status,
                created_by
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 'SUCCESS', ?)
            `,
            [
                folioId,
                stayId,
                outletId,
                paymentMethod,
                paymentAmount,
                referenceNo || null,
                remarks || null,
                userId
            ]
        );

        // --------------------------------------------------
        // 9. Recalculate folio
        // --------------------------------------------------

        const folioTotals =
            await recalculateFolio(
                connection,
                folioId,
                userId
            );
        
        const newTotalAmount =
            folioTotals.totalAmount;
        
        const newPaidAmount =
            folioTotals.paidAmount;
        
        const newBalanceAmount =
            folioTotals.balanceAmount;

        await connection.commit();

        // --------------------------------------------------
        // 11. Response
        // --------------------------------------------------

        return res.status(201).json({
            success: true,
            message: 'Folio payment added successfully',

            payment: {
                paymentId: paymentResult.insertId,
                folioId,
                stayId,
                paymentMethod,
                amount: paymentAmount,
                referenceNo: referenceNo || null,
                status: 'SUCCESS'
            },

            folio: {
                folioId,
                totalAmount: newTotalAmount,
                paidAmount: newPaidAmount,
                balanceAmount: Math.max(0, newBalanceAmount),
                status: 'OPEN'
            }
        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'addFolioPayment error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Failed to add folio payment',
            error: error.message
        });

    } finally {
        connection.release();
    }
};

exports.checkOut = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const userId = req.user.userId;
        const companyId = req.user.companyId;

        const stayId = Number(req.params.stayId);

        if (!stayId || Number.isNaN(stayId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        await connection.beginTransaction();

        // --------------------------------------------------
        // 1. Get user's outlet
        // --------------------------------------------------

        const [outlets] = await connection.query(
            `
            SELECT o.outlet_id
            FROM outlet o
            INNER JOIN user_outlet uo
                ON uo.outlet_id = o.outlet_id
            WHERE o.company_id = ?
              AND uo.user_id = ?
            LIMIT 1
            `,
            [companyId, userId]
        );

        if (!outlets.length) {
            await connection.rollback();

            return res.status(403).json({
                success: false,
                message: 'User has no outlet access'
            });
        }

        const outletId = outlets[0].outlet_id;

        // --------------------------------------------------
        // 2. Lock hotel stay
        // --------------------------------------------------

        const [stays] = await connection.query(
            `
            SELECT
                stay_id,
                outlet_id,
                guest_id,
                room_id,
                reservation_id,
                stay_no,
                check_in,
                expected_check_out,
                actual_check_out,
                adults,
                children,
                room_rate,
                status,
                remarks
            FROM hotel_stay
            WHERE stay_id = ?
              AND outlet_id = ?
            FOR UPDATE
            `,
            [stayId, outletId]
        );

        if (!stays.length) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Hotel stay not found'
            });
        }

        const stay = stays[0];

        // --------------------------------------------------
        // 3. Validate stay status
        // --------------------------------------------------

        if (stay.status === 'CHECKED_OUT') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'Guest is already checked out'
            });
        }

        if (stay.status !== 'CHECKED_IN') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Guest cannot be checked out from status ${stay.status}`
            });
        }

        // --------------------------------------------------
        // 4. Get and lock folio
        // --------------------------------------------------

        const [folios] = await connection.query(
            `
            SELECT *
            FROM hotel_folio
            WHERE stay_id = ?
              AND outlet_id = ?
            FOR UPDATE
            `,
            [stayId, outletId]
        );

        if (!folios.length) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message: 'No folio exists for this stay'
            });
        }

        const folio = folios[0];

        // --------------------------------------------------
        // 5. Folio must be OPEN
        // --------------------------------------------------

        if (folio.status !== 'OPEN') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Folio is already ${folio.status}`
            });
        }

        // --------------------------------------------------
        // 6. Recalculate actual successful payments
        // --------------------------------------------------
        const folioTotals =
            await recalculateFolio(
                connection,
                folio.folio_id,
                userId
            );
        
        const totalAmount =
            folioTotals.totalAmount;
        
        const paidAmount =
            folioTotals.paidAmount;
        
        const balanceAmount =
            folioTotals.balanceAmount;
        
        // --------------------------------------------------
        // 7. Prevent checkout with outstanding balance
        // --------------------------------------------------

        if (balanceAmount > 0.01) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Guest cannot be checked out because folio has outstanding balance',
                totalAmount,
                paidAmount,
                balanceAmount
            });
        }

        
        // --------------------------------------------------
        // 9. Settle folio
        // --------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_folio
            SET
                status = 'SETTLED',
                closed_at = NOW(),
                updated_by = ?
            WHERE folio_id = ?
            `,
            [
                userId,
                folio.folio_id
            ]
        );

        // --------------------------------------------------
        // 10. Check out the stay
        // --------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_stay
            SET
                status = 'CHECKED_OUT',
                actual_check_out = NOW(),
                updated_by = ?
            WHERE stay_id = ?
            `,
            [
                userId,
                stayId
            ]
        );
        // --------------------------------------------------
        // 10A. Complete the associated reservation
        // --------------------------------------------------

        if (stay.reservation_id) {
            await connection.query(
                `
                UPDATE hotel_reservation
                SET
                    status = 'COMPLETED',
                    updated_by = ?,
                    updated_at = NOW()
                WHERE reservation_id = ?
                  AND status = 'CHECKED_IN'
                `,
                [
                    userId,
                    stay.reservation_id
                ]
            );
        }
        // --------------------------------------------------
        // 11. Update current room
        //
        // hotel_stay.room_id is the current room.
        // --------------------------------------------------

        if (stay.room_id) {

            const [rooms] = await connection.query(
                `
                SELECT
                    room_id,
                    status
                FROM hotel_room
                WHERE room_id = ?
                  AND outlet_id = ?
                FOR UPDATE
                `,
                [
                    stay.room_id,
                    outletId
                ]
            );

            if (rooms.length) {

                await connection.query(
                    `
                    UPDATE hotel_room
                    SET
                    status = 'CLEANING',
                    housekeeping_status = 'DIRTY'
                    WHERE room_id = ?
                        AND outlet_id = ?
                    `,
                    [
                        stay.room_id,
                        outletId
                    ]
                );
            }
        }

        // --------------------------------------------------
        // 12. Close current stay-room assignment
        //
        // This preserves the room assignment history.
        // --------------------------------------------------

        await connection.query(
            `
            UPDATE hotel_stay_room
            SET
                assigned_until = NOW()
            WHERE stay_id = ?
              AND room_id = ?
              AND assigned_until IS NULL
            `,
            [
                stayId,
                stay.room_id
            ]
        );

        // --------------------------------------------------
        // 13. Commit transaction
        // --------------------------------------------------

        await connection.commit();

        return res.status(200).json({
            success: true,
            message: 'Guest checked out successfully',

            stay: {
                stayId: stay.stay_id,
                stayNo: stay.stay_no,
                status: 'CHECKED_OUT',
                actualCheckOut: new Date()
            },

            folio: {
                folioId: folio.folio_id,
                folioNo: folio.folio_no,
                totalAmount,
                paidAmount,
                balanceAmount: 0,
                status: 'SETTLED'
            },

            room: {
                roomId: stay.room_id,
                status: 'CLEANING'
            }
        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'checkOut error:',
            error
        );

        return res.status(500).json({
            success: false,
            message: 'Failed to check out guest',
            error: error.message
        });

    } finally {
        connection.release();
    }
};


// =========================================================
// GET RESERVATION LIST
//
// GET /hotel/reservations
//
// Query parameters:
//
// outletId       required
// status         optional
// fromDate       optional
// toDate         optional
// guest          optional
// reservationNo  optional
// =========================================================

exports.getReservations = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const {
            outletId,
            status,
            fromDate,
            toDate,
            guest,
            reservationNo
        } = req.query;


        const outlet =
            Number(outletId);


        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        if (!outlet) {

            return res.status(400).json({
                success: false,
                message: 'Invalid outletId'
            });

        }


        // -------------------------------------------------
        // Validate date filters if supplied
        // -------------------------------------------------

        if (fromDate && !isValidDate(fromDate)) {

            return res.status(400).json({
                success: false,
                message: 'Invalid fromDate'
            });

        }


        if (toDate && !isValidDate(toDate)) {

            return res.status(400).json({
                success: false,
                message: 'Invalid toDate'
            });

        }


        // -------------------------------------------------
        // Verify outlet access
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outlet,
                req
            );


        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }


        // -------------------------------------------------
        // Build query
        // -------------------------------------------------

        let sql = `
            SELECT

                hr.reservation_id,
                hr.outlet_id,
                hr.reservation_no,
                hr.guest_id,
                hr.room_type_id,
                hr.room_id,

                hr.booking_date,
                hr.expected_check_in,
                hr.expected_check_out,

                hr.adults,
                hr.children,

                hr.room_rate,
                hr.advance_amount,

                hr.status,
                hr.booking_source,
                hr.remarks,

                hr.created_by,
                hr.updated_by,
                hr.created_at,
                hr.updated_at,


                -- Guest
                hg.guest_code,
                hg.first_name AS guest_first_name,
                hg.last_name AS guest_last_name,
                hg.phone AS guest_phone,
                hg.email AS guest_email,


                -- Room type
                rt.type_code,
                rt.type_name,


                -- Room
                r.room_no,
                r.room_name,
                r.floor_no,
                r.status AS room_status,
                r.housekeeping_status

            FROM hotel_reservation hr

            INNER JOIN outlet o
                ON o.outlet_id = hr.outlet_id

            INNER JOIN user_outlet uo
                ON uo.outlet_id = hr.outlet_id

            INNER JOIN hotel_guest hg
                ON hg.guest_id = hr.guest_id

            INNER JOIN room_type rt
                ON rt.room_type_id = hr.room_type_id

            LEFT JOIN hotel_room r
                ON r.room_id = hr.room_id

            WHERE hr.outlet_id = ?

              AND o.company_id = ?
              AND uo.user_id = ?
        `;


        const params = [
            outlet,
            req.user.companyId,
            req.user.userId
        ];


        // -------------------------------------------------
        // Status filter
        // -------------------------------------------------

        if (
            status &&
            status.trim() !== '' &&
            status !== 'ALL'
        ) {

            sql += `
                AND hr.status = ?
            `;

            params.push(status.trim());

        }


        // -------------------------------------------------
        // From date
        //
        // Compare only date portion of expected check-in
        // -------------------------------------------------

        if (
            fromDate &&
            fromDate.trim() !== ''
        ) {

            sql += `
                AND DATE(hr.expected_check_in) >= ?
            `;

            params.push(
                fromDate.trim()
            );

        }


        // -------------------------------------------------
        // To date
        // -------------------------------------------------

        if (
            toDate &&
            toDate.trim() !== ''
        ) {

            sql += `
                AND DATE(hr.expected_check_in) <= ?
            `;

            params.push(
                toDate.trim()
            );

        }


        // -------------------------------------------------
        // Guest search
        //
        // Searches:
        // Guest code
        // First name
        // Last name
        // Phone
        // Email
        // -------------------------------------------------

        if (
            guest &&
            guest.trim() !== ''
        ) {

            sql += `
                AND (
                    hg.guest_code LIKE ?
                    OR hg.first_name LIKE ?
                    OR hg.last_name LIKE ?
                    OR hg.phone LIKE ?
                    OR hg.email LIKE ?
                )
            `;

            const search =
                `%${guest.trim()}%`;

            params.push(
                search,
                search,
                search,
                search,
                search
            );

        }


        // -------------------------------------------------
        // Reservation number
        // -------------------------------------------------

        if (
            reservationNo &&
            reservationNo.trim() !== ''
        ) {

            sql += `
                AND hr.reservation_no LIKE ?
            `;

            params.push(
                `%${reservationNo.trim()}%`
            );

        }


        // -------------------------------------------------
        // Order
        // -------------------------------------------------

        sql += `
            ORDER BY
                hr.expected_check_in ASC,
                hr.reservation_id DESC
        `;


        const [rows] =
            await connection.query(
                sql,
                params
            );


        // -------------------------------------------------
        // Response
        // -------------------------------------------------

        return res.json({

            success: true,

            count: rows.length,

            reservations:
                rows.map(row => ({

                    reservationId:
                        row.reservation_id,

                    reservationNo:
                        row.reservation_no,


                    guest: {

                        guestId:
                            row.guest_id,

                        guestCode:
                            row.guest_code,

                        firstName:
                            row.guest_first_name,

                        lastName:
                            row.guest_last_name,

                        phone:
                            row.guest_phone,

                        email:
                            row.guest_email
                    },


                    roomType: {

                        roomTypeId:
                            row.room_type_id,

                        typeCode:
                            row.type_code,

                        typeName:
                            row.type_name
                    },


                    room:
                        row.room_id
                            ? {

                                roomId:
                                    row.room_id,

                                roomNo:
                                    row.room_no,

                                roomName:
                                    row.room_name,

                                floorNo:
                                    row.floor_no,

                                status:
                                    row.room_status,

                                housekeepingStatus:
                                    row.housekeeping_status

                            }
                            : null,


                    bookingDate:
                        row.booking_date,

                    expectedCheckIn:
                        row.expected_check_in,

                    expectedCheckOut:
                        row.expected_check_out,


                    adults:
                        row.adults,

                    children:
                        row.children,


                    roomRate:
                        row.room_rate,

                    advanceAmount:
                        row.advance_amount,


                    status:
                        row.status,

                    bookingSource:
                        row.booking_source,

                    remarks:
                        row.remarks,


                    createdAt:
                        row.created_at,

                    updatedAt:
                        row.updated_at

                }))
        });


    } catch (error) {

        console.error(
            'Get reservations error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                'Unable to get reservations'

        });

    } finally {

        connection.release();

    }

};


// =========================================================
// GET HOTEL GUESTS
//
// GET /hotel/guests
//
// Query:
// outletId       required
// search         optional
// =========================================================

exports.getHotelGuests = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const {
            outletId,
            search
        } = req.query;

        const outlet =
            Number(outletId);


        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        if (!outlet) {

            return res.status(400).json({
                success: false,
                message: 'Invalid outletId'
            });

        }


        // -------------------------------------------------
        // Authorization
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outlet,
                req
            );


        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }


        // -------------------------------------------------
        // Query
        // -------------------------------------------------

        let sql = `
            SELECT
                guest_id,
                guest_code,
                first_name,
                last_name,
                phone,
                email,
                address,
                id_type,
                id_number
            FROM hotel_guest
            WHERE outlet_id = ?
              AND is_active = TRUE
        `;

        const params = [outlet];


        // -------------------------------------------------
        // Search
        // -------------------------------------------------

        if (
            search &&
            search.trim() !== ''
        ) {

            sql += `
                AND (
                    guest_code LIKE ?
                    OR first_name LIKE ?
                    OR last_name LIKE ?
                    OR phone LIKE ?
                    OR email LIKE ?
                )
            `;

            const searchValue =
                `%${search.trim()}%`;

            params.push(
                searchValue,
                searchValue,
                searchValue,
                searchValue,
                searchValue
            );
        }


        sql += `
            ORDER BY
                first_name,
                last_name,
                guest_id DESC
        `;


        const [rows] =
            await connection.query(
                sql,
                params
            );


        // -------------------------------------------------
        // Response
        // -------------------------------------------------

        return res.json({

            success: true,

            count: rows.length,

            guests:
                rows.map(row => ({

                    guestId:
                        row.guest_id,

                    guestCode:
                        row.guest_code,

                    firstName:
                        row.first_name,

                    lastName:
                        row.last_name,

                    phone:
                        row.phone,

                    email:
                        row.email,

                    address:
                        row.address,

                    idType:
                        row.id_type,

                    idNumber:
                        row.id_number

                }))
        });


    } catch (error) {

        console.error(
            'Get hotel guests error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                'Unable to get hotel guests'

        });

    } finally {

        connection.release();

    }

};

// =========================================================
// GET ROOM TYPES
//
// GET /hotel/room-types
//
// Query:
// outletId       required
// =========================================================

exports.getRoomTypes = async (
    req,
    res
) => {

    const connection =
        await db.getConnection();

    try {

        const {
            outletId
        } = req.query;

        const outlet =
            Number(outletId);


        // -------------------------------------------------
        // Validation
        // -------------------------------------------------

        if (!outlet) {

            return res.status(400).json({
                success: false,
                message: 'Invalid outletId'
            });

        }


        // -------------------------------------------------
        // Authorization
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outlet,
                req
            );


        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }


        // -------------------------------------------------
        // Get room types
        // -------------------------------------------------

        const [rows] =
            await connection.query(
                `
                SELECT

                    room_type_id,
                    outlet_id,

                    type_code,
                    type_name,

                    capacity_adult,
                    capacity_child,

                    base_rate,

                    is_active

                FROM room_type

                WHERE outlet_id = ?
                  AND is_active = TRUE

                ORDER BY
                    type_name,
                    room_type_id
                `,
                [
                    outlet
                ]
            );


        // -------------------------------------------------
        // Response
        // -------------------------------------------------

        return res.json({

            success: true,

            count: rows.length,

            roomTypes:
                rows.map(row => ({

                    roomTypeId:
                        row.room_type_id,

                    outletId:
                        row.outlet_id,

                    typeCode:
                        row.type_code,

                    typeName:
                        row.type_name,

                    capacityAdult:
                        row.capacity_adult,

                    capacityChild:
                        row.capacity_child,

                    baseRate:
                        row.base_rate,

                    isActive:
                        Boolean(row.is_active)

                }))
        });


    } catch (error) {

        console.error(
            'Get room types error:',
            error
        );


        return res.status(500).json({

            success: false,

            message:
                'Unable to get room types'

        });

    } finally {

        connection.release();

    }

};


exports.createHotelGuest = async (req, res) => {
  let connection;

  try {
    const {
      outletId,
      firstName,
      lastName,
      phone,
      email,
      address,
      idType,
      idNumber,
    } = req.body;

    if (!outletId) {
      return res.status(400).json({
        success: false,
        message: 'outletId is required',
      });
    }

    if (!firstName || !firstName.trim()) {
      return res.status(400).json({
        success: false,
        message: 'First name is required',
      });
    }

    if (!phone || !phone.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Phone is required',
      });
    }

    connection = await db.getConnection();
    await connection.beginTransaction();
    // Verify outlet access
    await getAuthorizedOutlet(
      connection,
      outletId,
      req
    );

    // Check duplicate phone within outlet
    const [existing] = await connection.query(
      `
      SELECT guest_id
      FROM hotel_guest
      WHERE outlet_id = ?
        AND phone = ?
      LIMIT 1
      `,
      [
        outletId,
        phone.trim(),
      ]
    );

    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'A guest with this phone number already exists.',
        guestId: existing[0].guest_id,
      });
    }

    // Generate guest code
    const [lastGuest] = await connection.query(
      `
      SELECT guest_code
      FROM hotel_guest
      WHERE outlet_id = ?
      ORDER BY guest_id DESC
      LIMIT 1
      FOR UPDATE
      `,
      [outletId]
    );

    let nextNumber = 1;

    if (lastGuest.length > 0 && lastGuest[0].guest_code) {
      const match =
        lastGuest[0].guest_code.match(/(\d+)$/);

      if (match) {
        nextNumber = parseInt(match[1], 10) + 1;
      }
    }

    const guestCode =
      `GUEST-${String(nextNumber).padStart(6, '0')}`;

    const [result] = await connection.query(
      `
      INSERT INTO hotel_guest
      (
        outlet_id,
        guest_code,
        first_name,
        last_name,
        phone,
        email,
        address,
        id_type,
        id_number
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      [
        outletId,
        guestCode,
        firstName.trim(),
        lastName?.trim() || null,
        phone.trim(),
        email?.trim() || null,
        address?.trim() || null,
        idType?.trim() || null,
        idNumber?.trim() || null,
      ]
    );

    const [rows] = await connection.query(
      `
      SELECT
        guest_id,
        outlet_id,
        guest_code,
        first_name,
        last_name,
        phone,
        email,
        address,
        id_type,
        id_number
      FROM hotel_guest
      WHERE guest_id = ?
      `,
      [result.insertId]
    );

    await connection.commit();

    const guest = rows[0];

    return res.status(201).json({
      success: true,
      message: 'Guest created successfully',
      guest: {
        guestId: guest.guest_id,
        outletId: guest.outlet_id,
        guestCode: guest.guest_code,
        firstName: guest.first_name,
        lastName: guest.last_name,
        phone: guest.phone,
        email: guest.email,
        address: guest.address,
        idType: guest.id_type,
        idNumber: guest.id_number,
      },
    });
  } catch (error) {
    if (connection) {
      await connection.rollback();
    }

    console.error(
      'createHotelGuest error:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to create guest',
      error: error.message,
    });
  } finally {
    if (connection) {
      connection.release();
    }
  }
};




// =========================================================
// POST ROOM CHARGE FOR HOTEL STAY
//
// POST /hotel/folio/post-room-charge
//
// Body:
// {
//   "stayId": 4,
//   "businessDate": "2026-09-17"
// }
// =========================================================

exports.postRoomCharge = async (req, res) => {
    const connection = await db.getConnection();

    try {
        const userId = req.user.userId;
        const companyId = req.user.companyId;

        const stayId = Number(req.body.stayId);
        const businessDate =
            String(req.body.businessDate || '').trim();

        if (!stayId || Number.isNaN(stayId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid stayId'
            });
        }

        if (!/^\d{4}-\d{2}-\d{2}$/.test(businessDate)) {
            return res.status(400).json({
                success: false,
                message:
                    'businessDate must be in YYYY-MM-DD format'
            });
        }

        await connection.beginTransaction();

        // --------------------------------------------------
        // 1. Get and lock stay
        // --------------------------------------------------

        const [stays] = await connection.query(
            `
            SELECT
                hs.*,
                r.room_no,
                r.room_type_id,
                rt.tax_group_id
            FROM hotel_stay hs

            INNER JOIN hotel_room r
                ON r.room_id = hs.room_id

            INNER JOIN room_type rt
                ON rt.room_type_id = r.room_type_id

            INNER JOIN outlet o
                ON o.outlet_id = hs.outlet_id

            INNER JOIN user_outlet uo
                ON uo.outlet_id = hs.outlet_id

            WHERE hs.stay_id = ?
              AND o.company_id = ?
              AND uo.user_id = ?

            FOR UPDATE
            `,
            [
                stayId,
                companyId,
                userId
            ]
        );

        if (stays.length === 0) {
            await connection.rollback();

            return res.status(404).json({
                success: false,
                message: 'Hotel stay not found'
            });
        }

        const stay = stays[0];

        // --------------------------------------------------
        // 2. Stay must be checked in
        // --------------------------------------------------

        if (stay.status !== 'CHECKED_IN') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Room charge cannot be posted for stay status ${stay.status}`
            });
        }

        // --------------------------------------------------
        // 3. Validate business date
        //
        // Room is charged for:
        // check-in date <= business date < checkout date
        // --------------------------------------------------

        const checkInDate =
            new Date(stay.check_in)
                .toISOString()
                .substring(0, 10);

        const expectedCheckOutDate =
            new Date(stay.expected_check_out)
                .toISOString()
                .substring(0, 10);

        if (businessDate < checkInDate) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Room charge date cannot be before check-in date'
            });
        }

        if (businessDate >= expectedCheckOutDate) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Room charge date must be before expected check-out date'
            });
        }

        // --------------------------------------------------
        // 4. Get / create folio
        // --------------------------------------------------

        const [folios] = await connection.query(
            `
            SELECT *
            FROM hotel_folio
            WHERE stay_id = ?
              AND outlet_id = ?
            LIMIT 1
            FOR UPDATE
            `,
            [
                stayId,
                stay.outlet_id
            ]
        );

        let folio;

        if (folios.length > 0) {
            folio = folios[0];
        } else {
            const folioNo =
                await generateFolioNo(
                    connection,
                    stay.outlet_id
                );

            const [folioResult] =
                await connection.query(
                    `
                    INSERT INTO hotel_folio
                    (
                        outlet_id,
                        stay_id,
                        folio_no,
                        status,
                        total_amount,
                        paid_amount,
                        balance_amount,
                        created_by,
                        updated_by
                    )
                    VALUES
                    (
                        ?,
                        ?,
                        ?,
                        'OPEN',
                        0.00,
                        0.00,
                        0.00,
                        ?,
                        ?
                    )
                    `,
                    [
                        stay.outlet_id,
                        stayId,
                        folioNo,
                        userId,
                        userId
                    ]
                );

            folio = {
                folio_id: folioResult.insertId,
                folio_no: folioNo,
                status: 'OPEN',
                total_amount: 0,
                paid_amount: 0,
                balance_amount: 0
            };
        }

        if (folio.status !== 'OPEN') {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    `Hotel folio is already ${folio.status}`
            });
        }

        // --------------------------------------------------
        // 5. Check whether this date was already posted
        // --------------------------------------------------

        const [existingPosting] =
            await connection.query(
                `
                SELECT
                    posting_id,
                    folio_entry_id,
                    room_rate,
                    status
                FROM hotel_room_charge_posting

                WHERE stay_id = ?
                  AND business_date = ?

                LIMIT 1

                FOR UPDATE
                `,
                [
                    stayId,
                    businessDate
                ]
            );

        if (existingPosting.length > 0) {
            await connection.commit();

            return res.json({
                success: true,
                alreadyPosted: true,
                message:
                    'Room charge for this date has already been posted',

                posting: {
                    postingId:
                        existingPosting[0].posting_id,

                    folioEntryId:
                        existingPosting[0].folio_entry_id,

                    businessDate,

                    roomRate:
                        Number(
                            existingPosting[0].room_rate
                        )
                }
            });
        }

        // --------------------------------------------------
        // 6. Room rate
        // --------------------------------------------------

        const roomRate =
            Number(stay.room_rate || 0);

        if (roomRate <= 0) {
            await connection.rollback();

            return res.status(400).json({
                success: false,
                message:
                    'Room rate must be greater than zero'
            });
        }

        // --------------------------------------------------
        // 7. Insert folio entry
        // --------------------------------------------------

        const description =
            `Room Charge - ${stay.room_no} - ${businessDate}`;

        const [entryResult] =
            await connection.query(
                `
                INSERT INTO hotel_folio_entry
                (
                    folio_id,
                    stay_id,
                    outlet_id,
                    entry_date,
                    entry_type,
                    description,
                    quantity,
                    rate,
                    amount,
                    source_type,
                    source_id,
                    status,
                    remarks,
                    created_by
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,
                    'ROOM_CHARGE',
                    ?,
                    1,
                    ?,
                    ?,
                    'ROOM_RATE',
                    ?,
                    'POSTED',
                    ?,
                    ?
                )
                `,
                [
                    folio.folio_id,
                    stayId,
                    stay.outlet_id,

                    // Use business date, not NOW().
                    `${businessDate} 00:00:00`,

                    description,

                    roomRate,
                    roomRate,

                    stayId,

                    `Room rate for ${businessDate}`,

                    userId
                ]
            );

        const folioEntryId =
            entryResult.insertId;
        // --------------------------------------------------
        // 8. Apply room taxes
        // --------------------------------------------------
       
        const taxResult =
            await applyFolioEntryTaxes(
                connection,
                folioEntryId,
                roomRate,
                stay.tax_group_id
            );
        
        const totalTaxAmount =
            taxResult.taxAmount;

        
        // --------------------------------------------------
        // 8a. Create posting-control record
        // --------------------------------------------------

        const [postingResult] =
            await connection.query(
                `
                INSERT INTO hotel_room_charge_posting
                (
                    outlet_id,
                    stay_id,
                    folio_id,
                    business_date,
                    room_rate,
                    status,
                    folio_entry_id,
                    created_by
                )
                VALUES
                (
                    ?,
                    ?,
                    ?,
                    ?,
                    ?,
                    'POSTED',
                    ?,
                    ?
                )
                `,
                [
                    stay.outlet_id,
                    stayId,
                    folio.folio_id,
                    businessDate,
                    roomRate,
                    folioEntryId,
                    userId
                ]
            );

       9 // --------------------------------------------------
        // 9. Recalculate folio
        // --------------------------------------------------



        const folioTotals =
        await recalculateFolio(
            connection,
            folio.folio_id,
            userId
        );
        
        const totalAmount =
            folioTotals.totalAmount;
        
        const paidAmount =
            folioTotals.paidAmount;
        
        const balanceAmount =
            folioTotals.balanceAmount;
       

        

        await connection.commit();

        return res.status(201).json({
            success: true,
            alreadyPosted: false,

            message:
                'Room charge posted successfully',

            posting: {
                postingId:
                    postingResult.insertId,

                folioEntryId,

                stayId,

                folioId:
                    folio.folio_id,

                folioNo:
                    folio.folio_no,

                businessDate,

                roomRate,

                totalAmount,

                paidAmount,

                balanceAmount
            }
        });

    } catch (error) {

        await connection.rollback();

        console.error(
            'Post room charge error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to post room charge',
            error: error.message
        });

    } finally {
        connection.release();
    }
};

// =========================================================
// GET HOUSEKEEPING ROOMS
//
// GET /hotel/housekeeping/rooms?outletId=1
//
// Returns rooms which are waiting for housekeeping.
// =========================================================

// =========================================================
// GET HOUSEKEEPING ROOMS
//
// GET /hotel/housekeeping/rooms?outletId=1
//
// Returns rooms waiting for or currently undergoing
// housekeeping.
// =========================================================

exports.getHousekeepingRooms = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const outletId =
            Number(req.query.outletId);

        if (!outletId) {

            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        // -------------------------------------------------
        // Verify outlet access
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outletId,
                req
            );

        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }

        // -------------------------------------------------
        // Get housekeeping rooms
        //
        // DIRTY       -> waiting to start
        // IN_PROGRESS -> housekeeping started
        // -------------------------------------------------

        const [rooms] =
            await connection.query(
                `
                SELECT
                    r.room_id,
                    r.outlet_id,
                    r.room_type_id,
                    r.room_no,
                    r.room_name,
                    r.floor_no,
                    r.status,
                    r.housekeeping_status,

                    rt.type_code,
                    rt.type_name,

                    hk.housekeeping_log_id,
                    hk.started_at

                FROM hotel_room r

                INNER JOIN room_type rt
                    ON rt.room_type_id = r.room_type_id

                LEFT JOIN hotel_housekeeping_log hk
                    ON hk.housekeeping_log_id = (
                        SELECT
                            h2.housekeeping_log_id

                        FROM hotel_housekeeping_log h2

                        WHERE h2.room_id = r.room_id
                          AND h2.status = 'STARTED'

                        ORDER BY
                            h2.housekeeping_log_id DESC

                        LIMIT 1
                    )

                WHERE r.outlet_id = ?
                  AND r.is_active = TRUE
                  AND r.status = 'CLEANING'
                  AND r.housekeeping_status IN
                      ('DIRTY', 'IN_PROGRESS')

                ORDER BY
                    r.floor_no,
                    r.room_no
                `,
                [
                    outletId
                ]
            );

        // -------------------------------------------------
        // Response
        // -------------------------------------------------

        return res.json({

            success: true,

            count:
                rooms.length,

            rooms:
                rooms.map(room => ({

                    roomId:
                        room.room_id,

                    outletId:
                        room.outlet_id,

                    roomTypeId:
                        room.room_type_id,

                    roomNo:
                        room.room_no,

                    roomName:
                        room.room_name,

                    floorNo:
                        room.floor_no,

                    roomTypeCode:
                        room.type_code,

                    roomTypeName:
                        room.type_name,

                    status:
                        room.status,

                    housekeepingStatus:
                        room.housekeeping_status,

                    housekeepingLogId:
                        room.housekeeping_log_id,

                    startedAt:
                        room.started_at

                }))

        });

    } catch (error) {

        console.error(
            'Get housekeeping rooms error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get housekeeping rooms'
        });

    } finally {

        connection.release();

    }
};

// =========================================================
// GET HOUSEKEEPING HISTORY
//
// GET /hotel/housekeeping/history
//
// Examples:
// /hotel/housekeeping/history?outletId=1
// /hotel/housekeeping/history?outletId=1&fromDate=2026-09-01&toDate=2026-09-19
// /hotel/housekeeping/history?outletId=1&roomId=5
// =========================================================

exports.getHousekeepingHistory = async (req, res) => {

    const connection = await db.getConnection();

    try {

        const outletId =
            Number(req.query.outletId);

        if (!outletId) {

            return res.status(400).json({
                success: false,
                message: 'outletId is required'
            });
        }

        const fromDate =
            req.query.fromDate?.toString() || null;

        const toDate =
            req.query.toDate?.toString() || null;

        const roomId =
            req.query.roomId
                ? Number(req.query.roomId)
                : null;

        // -------------------------------------------------
        // Verify outlet access
        // -------------------------------------------------

        const authorizedOutlet =
            await getAuthorizedOutlet(
                connection,
                outletId,
                req
            );

        if (!authorizedOutlet) {

            return res.status(403).json({
                success: false,
                message:
                    'You do not have access to this outlet'
            });

        }

        // -------------------------------------------------
        // Validate optional roomId
        // -------------------------------------------------

        if (
            roomId !== null &&
            (!Number.isInteger(roomId) || roomId <= 0)
        ) {

            return res.status(400).json({
                success: false,
                message: 'Invalid roomId'
            });
        }

        // -------------------------------------------------
        // Build filters
        // -------------------------------------------------

        const conditions = [
            'h.outlet_id = ?'
        ];

        const params = [
            outletId
        ];

        if (fromDate) {

            conditions.push(
                'h.started_at >= ?'
            );

            params.push(
                `${fromDate} 00:00:00`
            );
        }

        if (toDate) {

            conditions.push(
                'h.started_at < DATE_ADD(?, INTERVAL 1 DAY)'
            );

            params.push(
                toDate
            );
        }

        if (roomId !== null) {

            conditions.push(
                'h.room_id = ?'
            );

            params.push(
                roomId
            );
        }

        // -------------------------------------------------
        // Get history
        // -------------------------------------------------

        const [history] =
            await connection.query(
                `
                SELECT
                    h.housekeeping_log_id,
                    h.outlet_id,
                    h.room_id,
                    h.stay_id,

                    h.status,

                    h.started_at,
                    h.completed_at,
                    h.duration_minutes,

                    h.started_by,
                    h.completed_by,

                    h.remarks,

                    r.room_no,
                    r.room_name,

                    rt.type_code,
                    rt.type_name

                FROM hotel_housekeeping_log h

                INNER JOIN hotel_room r
                    ON r.room_id = h.room_id

                INNER JOIN room_type rt
                    ON rt.room_type_id = r.room_type_id

                WHERE ${conditions.join(' AND ')}

                ORDER BY
                    h.started_at DESC,
                    h.housekeeping_log_id DESC

                LIMIT 500
                `,
                params
            );

        // -------------------------------------------------
        // Response
        // -------------------------------------------------

        return res.json({

            success: true,

            count:
                history.length,

            history:
                history.map(row => ({

                    housekeepingLogId:
                        row.housekeeping_log_id,

                    outletId:
                        row.outlet_id,

                    roomId:
                        row.room_id,

                    roomNo:
                        row.room_no,

                    roomName:
                        row.room_name,

                    roomTypeCode:
                        row.type_code,

                    roomTypeName:
                        row.type_name,

                    stayId:
                        row.stay_id,

                    status:
                        row.status,

                    startedAt:
                        row.started_at,

                    completedAt:
                        row.completed_at,

                    durationMinutes:
                        row.duration_minutes,

                    startedBy:
                        row.started_by,

                    completedBy:
                        row.completed_by,

                    remarks:
                        row.remarks

                }))

        });

    } catch (error) {

        console.error(
            'Get housekeeping history error:',
            error
        );

        return res.status(500).json({
            success: false,
            message:
                'Unable to get housekeeping history'
        });

    } finally {

        connection.release();

    }
};