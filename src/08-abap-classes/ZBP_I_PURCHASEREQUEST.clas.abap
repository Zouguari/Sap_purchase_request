CLASS zbp_i_purchaserequest DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_purchaserequest.
ENDCLASS.

CLASS zbp_i_purchaserequest IMPLEMENTATION.
ENDCLASS.


"=============================================================
" Local Handler Class: PurchaseRequest (header)
"=============================================================
CLASS lhc_PurchaseRequest DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PurchaseRequest RESULT result.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseRequest~setInitialValues.

    METHODS validateHeader FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseRequest~validateHeader.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseRequest~submit RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseRequest~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseRequest~reject RESULT result.

ENDCLASS.

CLASS lhc_PurchaseRequest IMPLEMENTATION.

  METHOD get_instance_authorizations.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      FIELDS ( Requester Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    SELECT SINGLE FROM zpr_managers
      FIELDS bname
      WHERE bname = @sy-uname
      INTO @DATA(manager_row).
    DATA(is_manager) = xsdbool( sy-subrc = 0 ).

    result = VALUE #(
      FOR request IN requests
      (
        %tky = request-%tky

        %update = COND #(
          WHEN request-Status IS INITIAL OR request-Status = 'NEW'
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %delete = COND #(
          WHEN request-Status IS INITIAL OR request-Status = 'NEW'
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-submit = COND #(
          WHEN request-Requester IS INITIAL OR request-Requester = sy-uname
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-approve = COND #(
          WHEN is_manager = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-reject = COND #(
          WHEN is_manager = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )
      )
    ).

  ENDMETHOD.

  METHOD setInitialValues.

    MODIFY ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      UPDATE FIELDS ( Status )
      WITH VALUE #(
        FOR key IN keys
        (
          %tky   = key-%tky
          Status = 'NEW'
        )
      ).

  ENDMETHOD.

  METHOD validateHeader.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      FIELDS ( Description Category Priority RequestedDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    LOOP AT headers INTO DATA(header).

      IF header-Description IS INITIAL.
        APPEND VALUE #( %tky = header-%tky ) TO failed-PurchaseRequest.
        APPEND VALUE #(
          %tky = header-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '003'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequest.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD submit.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    LOOP AT headers INTO DATA(header).

      IF header-Status <> 'NEW'.
        APPEND VALUE #( %tky = header-%tky ) TO failed-PurchaseRequest.
        APPEND VALUE #(
          %tky = header-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '004'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequest.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_purchaserequest IN LOCAL MODE
        ENTITY PurchaseRequest
        UPDATE FIELDS ( Status )
        WITH VALUE #(
          (
            %tky   = header-%tky
            Status = 'SUBMITTED'
          )
        ).

    ENDLOOP.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated_headers).

    result = VALUE #( FOR upd IN updated_headers ( %tky = upd-%tky %param = upd ) ).

  ENDMETHOD.

  METHOD approve.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    LOOP AT headers INTO DATA(header).

      IF header-Status <> 'SUBMITTED'.
        APPEND VALUE #( %tky = header-%tky ) TO failed-PurchaseRequest.
        APPEND VALUE #(
          %tky = header-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '005'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequest.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_purchaserequest IN LOCAL MODE
        ENTITY PurchaseRequest
        UPDATE FIELDS ( Status )
        WITH VALUE #(
          (
            %tky   = header-%tky
            Status = 'APPROVED'
          )
        ).

    ENDLOOP.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated_headers).

    result = VALUE #( FOR upd IN updated_headers ( %tky = upd-%tky %param = upd ) ).

  ENDMETHOD.

  METHOD reject.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(headers).

    LOOP AT headers INTO DATA(header).

      DATA(key_with_param) = keys[ KEY entity %tky = header-%tky ].

      IF header-Status <> 'SUBMITTED'.
        APPEND VALUE #( %tky = header-%tky ) TO failed-PurchaseRequest.
        APPEND VALUE #(
          %tky = header-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '006'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequest.
        CONTINUE.
      ENDIF.

      IF key_with_param-%param-reject_reason IS INITIAL.
        APPEND VALUE #( %tky = header-%tky ) TO failed-PurchaseRequest.
        APPEND VALUE #(
          %tky = header-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '007'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequest.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_purchaserequest IN LOCAL MODE
        ENTITY PurchaseRequest
        UPDATE FIELDS ( Status RejectReason )
        WITH VALUE #(
          (
            %tky         = header-%tky
            Status       = 'REJECTED'
            RejectReason = key_with_param-%param-reject_reason
          )
        ).

    ENDLOOP.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated_headers).

    result = VALUE #( FOR upd IN updated_headers ( %tky = upd-%tky %param = upd ) ).

  ENDMETHOD.

ENDCLASS.


"=============================================================
" Local Handler Class: PurchaseRequestItem
"=============================================================
CLASS lhc_PurchaseRequestItem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateItemAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseRequestItem~calculateItemAmount.

    METHODS calculateTotalAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseRequestItem~calculateTotalAmount.

    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseRequestItem~validateItem.

ENDCLASS.

CLASS lhc_PurchaseRequestItem IMPLEMENTATION.

  METHOD calculateItemAmount.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequestItem
      FIELDS ( Quantity Price )
      WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequestItem
      UPDATE FIELDS ( ItemAmount )
      WITH VALUE #(
        FOR item IN items
        (
          %tky       = item-%tky
          ItemAmount = item-Quantity * item-Price
        )
      ).

  ENDMETHOD.

  METHOD calculateTotalAmount.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequestItem BY \_PurchaseRequest
      FIELDS ( PrId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(parents).

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequest BY \_Item
      FIELDS ( ItemAmount )
      WITH CORRESPONDING #( parents )
      RESULT DATA(items).

    LOOP AT parents INTO DATA(parent).

      DATA(total) = CONV zpr_hdr-total_amount( 0 ).

      LOOP AT items INTO DATA(item) WHERE PrId = parent-PrId.
        total = total + item-ItemAmount.
      ENDLOOP.

      MODIFY ENTITIES OF zi_purchaserequest IN LOCAL MODE
        ENTITY PurchaseRequest
        UPDATE FIELDS ( TotalAmount )
        WITH VALUE #(
          (
            %tky        = parent-%tky
            TotalAmount = total
          )
        ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateItem.

    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY PurchaseRequestItem
      FIELDS ( Quantity Product )
      WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).

      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-PurchaseRequestItem.
        APPEND VALUE #(
          %tky = item-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '001'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequestItem.
      ENDIF.

      IF item-Product IS INITIAL.
        APPEND VALUE #( %tky = item-%tky ) TO failed-PurchaseRequestItem.
        APPEND VALUE #(
          %tky = item-%tky
          %msg = new_message(
            id       = 'ZPR_MSG'
            number   = '002'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-PurchaseRequestItem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
