const express = require('express');
const router = express.Router();

const hotelController =
    require('../controller/hotelController');

const authenticate =
    require('../middleware/authMiddleware');


// ---------------------------------------------------------
// ROOM AVAILABILITY
// ---------------------------------------------------------

router.post(
    '/rooms/availability',
    authenticate,
    hotelController.getRoomAvailability
);

router.post(
    '/stays/check-in',
    authenticate,
    hotelController.checkIn
);

// ---------------------------------------------------------
// RESERVATIONS
// ---------------------------------------------------------

router.get(
    '/reservations',
    authenticate,
    hotelController.getReservations
);

router.post(
    '/reservations',
    authenticate,
    hotelController.createReservation
);

router.get(
    '/reservations/:reservationId',
    authenticate,
    hotelController.getReservation
);

router.put(
    '/reservations/:reservationId',
    authenticate,
    hotelController.updateReservation
);

router.post(
    '/reservations/:reservationId/cancel',
    authenticate,
    hotelController.cancelReservation
);

router.post(
    '/stays/:stayId/credential',
    authenticate,
    hotelController.createGuestCredential
);

router.get(
    '/stays/:stayId/credentials',
    authenticate,
    hotelController.getStayCredentials
);

router.post(
    '/credentials/:credentialId/revoke',
    authenticate,
    hotelController.revokeCredential
);


router.post(
    '/stays/:stayId/check-out',
    authenticate,
    hotelController.checkOut
);


// ---------------------------------------------------------
// HOUSEKEEPING
// ---------------------------------------------------------

router.post(
    '/rooms/:roomId/housekeeping-start',
    authenticate,
    hotelController.housekeepingStart
);

router.post(
    '/rooms/:roomId/housekeeping-complete',
    authenticate,
    hotelController.housekeepingComplete
);



// ---------------------------------------------------------
// HOTEL FOLIO
// ---------------------------------------------------------

router.post(
    '/stays/:stayId/folio',
    authenticate,
    hotelController.createOrGetFolio
);

router.get(
    '/stays/:stayId/folio',
    authenticate,
    hotelController.getStayFolio
);


router.post(
    '/folio/charge-restaurant-bill',
    authenticate,
    hotelController.chargeRestaurantBill
);


// ---------------------------------------------------------
// HOTEL FOLIO
// ---------------------------------------------------------



router.get(
    '/stays/active',
    authenticate,
    hotelController.getActiveStays
);

router.post(
    '/folio/add-charge',
    authenticate,
    hotelController.addFolioCharge
);

router.post(
    '/folio/payment',
    authenticate,
    hotelController.addFolioPayment
);
-



router.post(
  '/guests',
  authenticate,
  hotelController.createHotelGuest
);

router.get(
    '/guests',
    authenticate,
    hotelController.getHotelGuests
);


// ---------------------------------------------------------
// ROOM TYPES
// ---------------------------------------------------------

router.get(
    '/room-types',
    authenticate,
    hotelController.getRoomTypes
);

router.post(
    '/folio/post-room-charge',
    authenticate,
    hotelController.postRoomCharge
);

router.get(
    '/housekeeping/rooms',
    authenticate,
    hotelController.getHousekeepingRooms
);


router.get(
    '/housekeeping/history',
    authenticate,
    hotelController.getHousekeepingHistory
);

module.exports = router;